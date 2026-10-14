#import "RSAppDetailViewController.h"
#import "RSAPI.h"
#import "RSAppCell.h"
#import "RSAppListViewController.h"
#import "RSDetailTabs.h"
#import "RSIconView.h"
#import "RSImageCache.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"
#import "RSVersionsViewController.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat RSScreenshotHeight = 300;

typedef NS_ENUM(NSInteger, RSDetailTab) { RSDetailTabDetails, RSDetailTabReviews, RSDetailTabRelated };

static NSString *RSPlainText(NSString *html) {
    NSString *text = html ?: @"";
    for (NSArray *pair in @[@[@"<br/>", @"\n"], @[@"<br />", @"\n"], @[@"<br>", @"\n"], @[@"&amp;", @"&"],
                            @[@"&quot;", @"\""], @[@"&#39;", @"'"], @[@"&lt;", @"<"], @[@"&gt;", @">"]])
        text = [text stringByReplacingOccurrencesOfString:pair[0] withString:pair[1]];
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@interface RSAppDetailViewController () <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>
@end

@implementation RSAppDetailViewController {
    RSAppSummary *_summary;
    NSDictionary *_app;
    NSArray *_installables;
    NSString *_loadError;
    RSRating *_rating;
    NSArray *_shots;
    NSArray *_reviews;
    NSArray *_related;
    BOOL _reviewsLoaded, _relatedLoaded;
    RSDetailTab _tab;

    UITableView *_tableView;
    UIView *_header;
    RSIconView *_iconView;
    UILabel *_nameLabel, *_developerLabel, *_ratingLabel, *_noteLabel;
    UIImageView *_starsView;
    RSPriceButton *_button;
    RSDetailTabs *_tabs;
    UIView *_infoView;
    UIScrollView *_shotsView;
}

- (instancetype)initWithSummary:(RSAppSummary *)summary {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _summary = summary;
        self.title = @"Info";
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        for (NSString *name in @[RSInstallerDidChangeNotification, RSInstalledAppsDidChangeNotification])
            [center addObserver:self selector:@selector(updateButton) name:name object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    view.backgroundColor = [RSTheme backgroundColor];
    _tableView = [[UITableView alloc] initWithFrame:view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [view addSubview:_tableView];
    self.view = view;
    [self buildHeader];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share)];
    [self load];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    NSIndexPath *selected = _tableView.indexPathForSelectedRow;
    if (selected) [_tableView deselectRowAtIndexPath:selected animated:animated];
}

#pragma mark - Header

- (void)buildHeader {
    CGFloat width = self.view.bounds.size.width;
    _header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 160)];
    _header.backgroundColor = RSColor(0xf4f4f4);

    _iconView = [[RSIconView alloc] initWithSize:74];
    _iconView.frame = CGRectMake(12, 13, 74, 74);
    _iconView.iconURL = _summary.iconURL;

    CGFloat x = 100;
    _nameLabel = RSLabel([UIFont boldSystemFontOfSize:18], [RSTheme textColor]);
    _nameLabel.numberOfLines = 2;
    _developerLabel = RSLabel([UIFont systemFontOfSize:14], RSColor(0x6f6f6f));
    _starsView = [UIImageView new];
    _ratingLabel = RSLabel([UIFont systemFontOfSize:11], RSColor(0x7a7a7a));
    _noteLabel = RSLabel([UIFont systemFontOfSize:12], RSColor(0x8a8a8a));
    _noteLabel.numberOfLines = 2;
    _noteLabel.frame = CGRectMake(x, 92, width - x - 12, 30);
    for (UILabel *label in @[_nameLabel, _developerLabel, _ratingLabel, _noteLabel]) {
        label.shadowColor = [UIColor whiteColor];
        label.shadowOffset = CGSizeMake(0, 1);
    }

    _button = [RSPriceButton buttonWithRightEdge:width - 12 y:66];
    _button.priceText = _summary.priceText;
    [_button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];

    _tabs = [[RSDetailTabs alloc] initWithFrame:CGRectMake(0, 102, width, 50)
                                         titles:@[@"Details", @"Beoordelingen", @"Verwant"]];
    [_tabs addTarget:self action:@selector(tabChanged) forControlEvents:UIControlEventValueChanged];

    for (UIView *view in @[_iconView, _nameLabel, _developerLabel, _starsView, _ratingLabel, _noteLabel, _button, _tabs])
        [_header addSubview:view];
    [self updateHeader];
}

- (void)updateHeader {
    CGFloat width = _header.bounds.size.width, x = 100;
    CGFloat textWidth = width - x - 12;
    _nameLabel.text = RSString(_app[@"name"]) ?: _summary.name;
    _developerLabel.text = RSString(_app[@"developer"]) ?: _summary.developer;

    CGSize nameSize = [_nameLabel.text sizeWithFont:_nameLabel.font constrainedToSize:CGSizeMake(textWidth, 44)
                                      lineBreakMode:NSLineBreakByTruncatingTail];
    _nameLabel.frame = CGRectMake(x, 12, textWidth, nameSize.height);
    _developerLabel.frame = CGRectMake(x, CGRectGetMaxY(_nameLabel.frame) + 1, textWidth, 18);

    if (_rating.average > 0) {
        _starsView.image = [RSTheme starsWithRating:_rating.average size:11];
        _starsView.frame = CGRectMake(x, 74, _starsView.image.size.width, _starsView.image.size.height);
        _ratingLabel.text = [NSString stringWithFormat:@"(%ld)", (long)_rating.count];
        _ratingLabel.frame = CGRectMake(CGRectGetMaxX(_starsView.frame) + 4, 71, 70, 16);
    }
    if (!_summary.priceText && _rating.priceText) _button.priceText = _rating.priceText;

    if (_loadError)
        _noteLabel.text = _loadError;
    else if (_app && !_installables.count)
        _noteLabel.text = [NSString stringWithFormat:@"Geen versie in het archief werkt op iOS %@.", RSSystemVersion()];
    else
        _noteLabel.text = nil;
    _noteLabel.hidden = !_noteLabel.text;
    CGFloat top = _noteLabel.hidden ? 102 : 124;
    _tabs.frame = CGRectMake(0, top, width, 50);
    _header.frame = CGRectMake(0, 0, width, top + 50);
    _tableView.tableHeaderView = _header;
    [self updateButton];
}

- (void)updateButton {
    RSInstallable *best = _installables.firstObject;
    NSString *bundleID = RSString(_app[@"bundle_id"]) ?: _summary.bundleID;
    NSString *installed = RSInstalledVersion(bundleID);
    _button.hidden = _app && !best && !installed;
    if (_button.priceState == RSPriceStateConfirm) return;
    if ([RSInstaller isInstalling:_summary.appStoreID])
        _button.priceState = RSPriceStateInstalling;
    else if (installed && best && !RSVersionLessOrEqual(best.version, installed))
        _button.priceState = RSPriceStateUpdate;
    else if (installed || (bundleID && RSInstalledApps()[bundleID]))
        _button.priceState = RSPriceStateOpen;
    else
        _button.priceState = RSPriceStatePrice;
}

- (void)buttonTapped {
    switch (_button.priceState) {
        case RSPriceStateOpen:
            [RSInstaller open:RSString(_app[@"bundle_id"]) ?: _summary.bundleID];
            break;
        case RSPriceStateConfirm:
            if (!_app) break;
            if ([RSInstaller install:_installables.firstObject ofApp:_app])
                [_button setPriceState:RSPriceStateInstalling animated:YES];
            else
                [self updateButton];
            break;
        case RSPriceStateInstalling:
            break;
        default:
            [_button setPriceState:RSPriceStateConfirm animated:YES];
    }
}

- (void)share {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Annuleer"
        destructiveButtonTitle:nil otherButtonTitles:@"Open in Safari", @"Kopieer link", nil];
    [sheet showFromTabBar:self.tabBarController.tabBar];
}

- (NSString *)webLink {
    return RSString(_app[@"web_url"]) ?: [@"https://legacystore.app/app/" stringByAppendingString:_summary.appStoreID];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == 0) [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[self webLink]]];
    if (index == 1) [UIPasteboard generalPasteboard].string = [self webLink];
}

#pragma mark - Loading

- (NSString *)apiPath:(NSString *)suffix {
    return [NSString stringWithFormat:@"/api/v1/apps/%@%@", RSEscape(_summary.appStoreID), suffix];
}

- (void)load {
    __weak RSAppDetailViewController *weakSelf = self;
    [RSAPI getPath:[self apiPath:@""] query:nil completion:^(NSDictionary *json, NSError *error) {
        [weakSelf appLoaded:json error:error];
    }];
    [RSAPI getPath:[self apiPath:@"/ratings"] query:nil completion:^(id json, NSError *error) {
        RSAppDetailViewController *controller = weakSelf;
        if (!controller) return;
        controller->_rating = [RSRating ratingFromJSON:json];
        [controller updateHeader];
        if (controller->_tab == RSDetailTabReviews) [controller->_tableView reloadData];
    }];
}

- (void)appLoaded:(NSDictionary *)json error:(NSError *)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        _loadError = [NSString stringWithFormat:@"Kan deze app niet laden. %@", error.localizedDescription ?: @""];
        [self updateHeader];
        return;
    }
    _app = json;
    _installables = [RSInstallable installablesForApp:json];
    if (!_summary.genreID) _summary.genreID = RSString(json[@"genre_id"]);
    if (!_summary.bundleID) _summary.bundleID = RSString(json[@"bundle_id"]);
    _infoView = nil;
    [self updateHeader];
    [_tableView reloadData];

    NSString *version = ((RSInstallable *)_installables.firstObject).version;
    __weak RSAppDetailViewController *weakSelf = self;
    [RSAPI getPath:[self apiPath:@"/screenshots"] query:nil completion:^(id shots, NSError *shotsError) {
        RSAppDetailViewController *controller = weakSelf;
        NSArray *list = RSPreferredScreenshotSet(shots, version)[@"shots"];
        if (!controller || ![list isKindOfClass:[NSArray class]]) return;
        controller->_shots = list;
        controller->_shotsView = nil;
        [controller->_tableView reloadData];
    }];
}

- (void)loadReviews {
    if (_reviews) return;
    _reviews = @[];
    __weak RSAppDetailViewController *weakSelf = self;
    [RSAPI getPath:[self apiPath:@"/reviews"] query:@{@"limit": @50} completion:^(NSDictionary *json, NSError *error) {
        RSAppDetailViewController *controller = weakSelf;
        if (!controller) return;
        NSArray *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
        controller->_reviews = [data isKindOfClass:[NSArray class]] ? data : @[];
        controller->_reviewsLoaded = YES;
        if (controller->_tab == RSDetailTabReviews) [controller->_tableView reloadData];
    }];
}

- (void)loadRelated {
    NSString *genreID = _summary.genreID;
    if (_related || !genreID) return;
    _related = @[];
    __weak RSAppDetailViewController *weakSelf = self;
    NSDictionary *query = @{@"genre": genreID, @"sort": @"versions", @"limit": @26};
    [RSAPI getPath:@"/api/v1/apps" query:query completion:^(NSDictionary *json, NSError *error) {
        RSAppDetailViewController *controller = weakSelf;
        if (!controller) return;
        NSMutableArray *apps = [NSMutableArray array];
        for (NSDictionary *app in json[@"data"]) {
            RSAppSummary *summary = [RSAppSummary summaryWithApp:app];
            if (summary && ![summary.appStoreID isEqualToString:controller->_summary.appStoreID]) [apps addObject:summary];
        }
        controller->_related = apps;
        controller->_relatedLoaded = YES;
        if (controller->_tab == RSDetailTabRelated) [controller->_tableView reloadData];
    }];
}

- (void)tabChanged {
    _tab = _tabs.selectedIndex;
    if (_tab == RSDetailTabReviews) [self loadReviews];
    if (_tab == RSDetailTabRelated) [self loadRelated];
    [_tableView reloadData];
}

#pragma mark - Details rows

- (NSArray *)detailRows {
    NSMutableArray *rows = [NSMutableArray array];
    if (_shots.count) [rows addObject:@"shots"];
    if (_app) [rows addObjectsFromArray:@[@"info", @"versions", @"web"]];
    return rows;
}

- (UIScrollView *)shotsView {
    if (_shotsView) return _shotsView;
    _shotsView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, _tableView.bounds.size.width, RSScreenshotHeight + 28)];
    _shotsView.showsHorizontalScrollIndicator = NO;
    _shotsView.scrollsToTop = NO;
    CGFloat x = 12;
    for (NSDictionary *shot in _shots) {
        if (![shot isKindOfClass:[NSDictionary class]]) continue;
        CGFloat w = [shot[@"width"] doubleValue], h = [shot[@"height"] doubleValue];
        NSString *url = RSString(shot[@"url"]);
        if (w <= 0 || h <= 0 || !url) continue;
        CGFloat scale = MIN(RSScreenshotHeight / h, 290 / w);
        CGSize size = CGSizeMake(round(w * scale), round(h * scale));
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:
            CGRectMake(x, 14 + round((RSScreenshotHeight - size.height) / 2), size.width, size.height)];
        imageView.backgroundColor = RSColor(0xd8d8d8);
        imageView.layer.borderColor = RSColor(0xa8a8a8).CGColor;
        imageView.layer.borderWidth = 1;
        imageView.layer.shadowColor = [UIColor blackColor].CGColor;
        imageView.layer.shadowOpacity = 0.25;
        imageView.layer.shadowRadius = 2;
        imageView.layer.shadowOffset = CGSizeMake(0, 1);
        imageView.layer.shadowPath = [UIBezierPath bezierPathWithRect:imageView.bounds].CGPath;
        __weak UIImageView *weakView = imageView;
        [[RSImageCache sharedCache] loadImageAtURL:[NSURL URLWithString:url] completion:^(UIImage *image) {
            weakView.image = image;
        }];
        [_shotsView addSubview:imageView];
        x += size.width + 12;
    }
    _shotsView.contentSize = CGSizeMake(x, _shotsView.bounds.size.height);
    return _shotsView;
}

- (NSArray *)infoPairs {
    RSInstallable *best = _installables.firstObject;
    NSMutableArray *pairs = [NSMutableArray array];
    void (^add)(NSString *, NSString *) = ^(NSString *key, NSString *value) {
        if (value.length) [pairs addObject:@[key, value]];
    };
    add(@"Verkoper", RSString(_app[@"developer"]));
    add(@"Categorie", [RSGenres nameForID:RSString(_app[@"genre_id"])] ?:
        [RSGenres dutchName:RSString(_app[@"genre"]) genreID:RSString(_app[@"genre_id"])]);
    add(@"Bijgewerkt", RSFormatDate(best.releaseDate));
    add(@"Versie", best.version);
    add(@"Grootte", RSFormatBytes(best.size));
    add(@"Vereist", best.minimumOS ? [NSString stringWithFormat:@"Geschikt voor iPhone en iPod touch. Vereist iOS %@ of nieuwer.",
                                      best.minimumOS] : nil);
    NSString *installed = RSInstalledVersion(RSString(_app[@"bundle_id"]));
    add(@"Op iPhone", installed ? [@"Versie " stringByAppendingString:installed] : nil);
    NSArray *versions = [_app[@"versions"] isKindOfClass:[NSArray class]] ? _app[@"versions"] : nil;
    add(@"Archief", versions.count ? [NSString stringWithFormat:@"%lu versies, %lu voor deze iPhone",
        (unsigned long)versions.count, (unsigned long)_installables.count] : nil);
    add(@"Copyright", RSString(_app[@"copyright"]));
    return pairs;
}

- (UIView *)infoView {
    if (_infoView) return _infoView;
    CGFloat width = _tableView.bounds.size.width;
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 100)];
    UILabel *title = RSLabel([UIFont boldSystemFontOfSize:17], [RSTheme textColor]);
    title.frame = CGRectMake(14, 12, width - 28, 22);
    title.text = @"Informatie";
    [view addSubview:title];
    CGFloat y = 42, keyWidth = 80, valueX = 14 + keyWidth + 10, valueWidth = width - valueX - 14;
    UIFont *font = [UIFont systemFontOfSize:14];
    for (NSArray *pair in [self infoPairs]) {
        UILabel *key = RSLabel(font, RSColor(0x8c8c8c));
        key.frame = CGRectMake(14, y, keyWidth, 18);
        key.textAlignment = NSTextAlignmentRight;
        key.text = pair[0];
        CGSize size = [pair[1] sizeWithFont:font constrainedToSize:CGSizeMake(valueWidth, 200)];
        UILabel *value = RSLabel(font, RSColor(0x3c3c3c));
        value.frame = CGRectMake(valueX, y, valueWidth, size.height);
        value.numberOfLines = 0;
        value.text = pair[1];
        for (UILabel *label in @[key, value]) {
            label.shadowColor = [UIColor whiteColor];
            label.shadowOffset = CGSizeMake(0, 1);
            [view addSubview:label];
        }
        y += MAX(18, size.height) + 3;
    }
    view.frame = CGRectMake(0, 0, width, y + 14);
    [view addSubview:[RSTheme engravedLineWithWidth:width]];
    _infoView = view;
    return view;
}

#pragma mark - Reviews rows

- (UIFont *)reviewBodyFont {
    return [UIFont systemFontOfSize:13];
}

- (CGFloat)reviewBodyHeight:(NSDictionary *)review {
    CGSize size = [RSPlainText(RSString(review[@"body"])) sizeWithFont:[self reviewBodyFont]
        constrainedToSize:CGSizeMake(_tableView.bounds.size.width - 28, 2000)];
    return size.height;
}

- (UITableViewCell *)reviewCell:(NSInteger)index {
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:@"review"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"review"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        CGFloat width = _tableView.bounds.size.width;
        UILabel *title = RSLabel([UIFont boldSystemFontOfSize:14], [RSTheme textColor]);
        title.frame = CGRectMake(14, 10, width - 28, 18);
        title.tag = 1;
        UIImageView *stars = [[UIImageView alloc] initWithFrame:CGRectMake(14, 32, 0, 0)];
        stars.tag = 2;
        UILabel *byline = RSLabel([UIFont systemFontOfSize:12], RSColor(0x8a8a8a));
        byline.frame = CGRectMake(14 + 70, 29, width - 28 - 70, 16);
        byline.tag = 3;
        UILabel *body = RSLabel([self reviewBodyFont], RSColor(0x3c3c3c));
        body.numberOfLines = 0;
        body.tag = 4;
        for (UIView *view in @[title, stars, byline, body]) [cell.contentView addSubview:view];
    }
    NSDictionary *review = _reviews[index];
    cell.backgroundView = [RSTheme rowBackgroundDark:index % 2 selected:NO];
    ((UILabel *)[cell.contentView viewWithTag:1]).text =
        [NSString stringWithFormat:@"%ld. %@", (long)index + 1, RSPlainText(RSString(review[@"title"]))];
    UIImageView *stars = (UIImageView *)[cell.contentView viewWithTag:2];
    stars.image = [RSTheme starsWithRating:[review[@"stars"] doubleValue] size:11];
    stars.frame = (CGRect){stars.frame.origin, stars.image.size};
    NSMutableArray *by = [NSMutableArray array];
    if (RSString(review[@"author"])) [by addObject:[@"door " stringByAppendingString:RSString(review[@"author"])]];
    if (RSString(review[@"app_version"])) [by addObject:[@"versie " stringByAppendingString:RSString(review[@"app_version"])]];
    if (RSFormatDate(RSString(review[@"reviewed_at"]))) [by addObject:RSFormatDate(RSString(review[@"reviewed_at"]))];
    ((UILabel *)[cell.contentView viewWithTag:3]).text = [by componentsJoinedByString:@" – "];
    UILabel *body = (UILabel *)[cell.contentView viewWithTag:4];
    body.text = RSPlainText(RSString(review[@"body"]));
    body.frame = CGRectMake(14, 50, _tableView.bounds.size.width - 28, [self reviewBodyHeight:review]);
    return cell;
}

- (UITableViewCell *)ratingSummaryCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    CGFloat width = _tableView.bounds.size.width;
    UILabel *title = RSLabel([UIFont boldSystemFontOfSize:17], [RSTheme textColor]);
    title.frame = CGRectMake(14, 12, width - 28, 22);
    title.text = @"Beoordelingen";
    [cell.contentView addSubview:title];
    UILabel *detail = RSLabel([UIFont systemFontOfSize:13], RSColor(0x7a7a7a));
    if (_rating.average > 0) {
        UIImageView *stars = [[UIImageView alloc] initWithImage:[RSTheme starsWithRating:_rating.average size:17]];
        stars.frame = (CGRect){CGPointMake(14, 42), stars.image.size};
        [cell.contentView addSubview:stars];
        detail.frame = CGRectMake(CGRectGetMaxX(stars.frame) + 8, 41, 180, 20);
        detail.text = [NSString stringWithFormat:@"%ld beoordelingen", (long)_rating.count];
    } else {
        detail.frame = CGRectMake(14, 41, width - 28, 20);
        detail.text = @"Nog geen gemiddelde beoordeling.";
    }
    [cell.contentView addSubview:detail];
    [cell.contentView addSubview:[RSTheme engravedLineWithWidth:width]];
    return cell;
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (_tab) {
        case RSDetailTabDetails: return [self detailRows].count;
        case RSDetailTabReviews: return 1 + MAX(1, _reviews.count);
        case RSDetailTabRelated: return MAX(1, _related.count);
    }
    return 0;
}

- (BOOL)isStatusRow:(NSIndexPath *)indexPath {
    if (_tab == RSDetailTabReviews) return indexPath.row == 1 && !_reviews.count;
    if (_tab == RSDetailTabRelated) return !_related.count;
    return NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isStatusRow:indexPath]) return 120;
    switch (_tab) {
        case RSDetailTabDetails: {
            NSString *row = [self detailRows][indexPath.row];
            if ([row isEqualToString:@"shots"]) return RSScreenshotHeight + 28;
            if ([row isEqualToString:@"info"]) return [self infoView].bounds.size.height;
            return 52;
        }
        case RSDetailTabReviews:
            if (indexPath.row == 0) return 76;
            return 60 + [self reviewBodyHeight:_reviews[indexPath.row - 1]];
        case RSDetailTabRelated:
            return [RSAppCell height];
    }
    return 44;
}

- (UITableViewCell *)plainCell:(UIView *)content {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell.contentView addSubview:content];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isStatusRow:indexPath]) {
        BOOL loading = _tab == RSDetailTabReviews ? !_reviewsLoaded : (!_relatedLoaded && _summary.genreID);
        NSString *text = loading ? @"Laden…" : _tab == RSDetailTabReviews ?
            @"Nog geen beoordelingen in het archief." : @"Geen verwante apps gevonden.";
        return [self plainCell:RSStatusView(tableView.bounds.size.width, text, loading)];
    }
    if (_tab == RSDetailTabReviews)
        return indexPath.row == 0 ? [self ratingSummaryCell] : [self reviewCell:indexPath.row - 1];
    if (_tab == RSDetailTabRelated) {
        RSAppCell *cell = [tableView dequeueReusableCellWithIdentifier:@"app"];
        if (!cell) cell = [[RSAppCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"app"];
        [cell configureWithSummary:_related[indexPath.row] showRank:NO dark:indexPath.row % 2];
        return cell;
    }

    NSString *row = [self detailRows][indexPath.row];
    if ([row isEqualToString:@"shots"]) return [self plainCell:[self shotsView]];
    if ([row isEqualToString:@"info"]) return [self plainCell:[self infoView]];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"link"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"link"];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
        cell.textLabel.textColor = [RSTheme textColor];
        cell.textLabel.shadowColor = [UIColor whiteColor];
        cell.textLabel.shadowOffset = CGSizeMake(0, 1);
        cell.textLabel.backgroundColor = cell.detailTextLabel.backgroundColor = [UIColor clearColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectedBackgroundView = [RSTheme rowBackgroundDark:NO selected:YES];
    }
    BOOL versions = [row isEqualToString:@"versions"];
    cell.backgroundView = [RSTheme rowBackgroundDark:!versions selected:NO];
    cell.textLabel.text = versions ? @"Versiegeschiedenis" : @"Bekijk op legacystore.app";
    cell.detailTextLabel.text = versions && _installables.count ? [NSString stringWithFormat:@"%lu", (unsigned long)_installables.count] : nil;
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isStatusRow:indexPath]) return nil;
    if (_tab == RSDetailTabRelated) return indexPath;
    if (_tab == RSDetailTabDetails) {
        NSString *row = [self detailRows][indexPath.row];
        if ([row isEqualToString:@"versions"] || [row isEqualToString:@"web"]) return indexPath;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_tab == RSDetailTabRelated) {
        RSAppDetailViewController *detail = [[RSAppDetailViewController alloc] initWithSummary:_related[indexPath.row]];
        [self.navigationController pushViewController:detail animated:YES];
        return;
    }
    NSString *row = [self detailRows][indexPath.row];
    if ([row isEqualToString:@"versions"]) {
        RSVersionsViewController *versions = [[RSVersionsViewController alloc] initWithApp:_app];
        [self.navigationController pushViewController:versions animated:YES];
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[self webLink]]];
    }
}

@end
