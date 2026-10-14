#import "RSSearchViewController.h"
#import "RSScrollView.h"
#import "RSAPI.h"
#import "RSAppDetailViewController.h"
#import "RSAppListViewController.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSSearchCard.h"
#import "RSTheme.h"
#import "RSUtil.h"

static const CGFloat RSCardWidth = 276;
static const CGFloat RSCardPitch = 288;

@interface RSPagerContainer : UIView
@property (nonatomic, weak) UIScrollView *scrollView;
@end

@implementation RSPagerContainer

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) return self.scrollView;
    return hit;
}

@end

@interface RSSearchViewController () <UISearchBarDelegate, UIScrollViewDelegate>
@end

@implementation RSSearchViewController {
    UISearchBar *_searchBar;
    RSPagerContainer *_container;
    UIScrollView *_pager;
    UILabel *_pageLabel;
    UIView *_status;
    UIButton *_dismissKeyboard;
    NSArray *_cards;
    NSUInteger _generation;
}

- (instancetype)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.title = @"Zoek";
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        for (NSString *name in @[RSInstallerDidChangeNotification, RSInstalledAppsDidChangeNotification])
            [center addObserver:self selector:@selector(refreshButtons) name:name object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    view.backgroundColor = [RSTheme backgroundColor];
    CGFloat width = view.bounds.size.width;

    _container = [[RSPagerContainer alloc] initWithFrame:CGRectMake(0, 44, width, view.bounds.size.height - 44)];
    _container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _container.clipsToBounds = YES;
    [view addSubview:_container];

    _pager = [[RSScrollView alloc] initWithFrame:CGRectMake(round((width - RSCardPitch) / 2), 0,
                                                            RSCardPitch, _container.bounds.size.height - 30)];
    _pager.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin |
                              UIViewAutoresizingFlexibleRightMargin;
    _pager.pagingEnabled = YES;
    _pager.clipsToBounds = NO;
    _pager.showsHorizontalScrollIndicator = NO;
    _pager.scrollsToTop = NO;
    _pager.delaysContentTouches = NO;
    _pager.delegate = self;
    [_container addSubview:_pager];
    _container.scrollView = _pager;

    _pageLabel = RSLabel([UIFont boldSystemFontOfSize:15], RSColor(0x6e6e6e));
    _pageLabel.frame = CGRectMake(0, _container.bounds.size.height - 30, width, 24);
    _pageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _pageLabel.textAlignment = NSTextAlignmentCenter;
    _pageLabel.shadowColor = [UIColor whiteColor];
    _pageLabel.shadowOffset = CGSizeMake(0, 1);
    [_container addSubview:_pageLabel];

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _searchBar.placeholder = @"Zoek in het archief";
    _searchBar.delegate = self;
    [view addSubview:_searchBar];

    _dismissKeyboard = [UIButton buttonWithType:UIButtonTypeCustom];
    _dismissKeyboard.frame = _container.frame;
    _dismissKeyboard.autoresizingMask = _container.autoresizingMask;
    _dismissKeyboard.hidden = YES;
    [_dismissKeyboard addTarget:_searchBar action:@selector(resignFirstResponder) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:_dismissKeyboard];

    self.view = view;
    [self showStatus:@"Zoek naar apps uit de geschiedenis\nvan de App Store." loading:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)showStatus:(NSString *)text loading:(BOOL)loading {
    [_status removeFromSuperview];
    _status = nil;
    if (!text && !loading) return;
    _status = RSStatusView(_container.bounds.size.width, text, loading);
    _status.center = CGPointMake(_container.bounds.size.width / 2, _container.bounds.size.height * 0.4);
    _status.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [_container addSubview:_status];
}

#pragma mark - Searching

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    _dismissKeyboard.hidden = NO;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    _dismissKeyboard.hidden = YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *term = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!term.length) return;
    [self showCards:@[]];
    [self showStatus:@"Zoeken…" loading:YES];
    NSUInteger generation = ++_generation;
    NSDictionary *query = @{@"q": term, @"sort": @"relevance", @"limit": @50};
    [RSAPI getPath:@"/api/v1/apps" query:query completion:^(NSDictionary *json, NSError *error) {
        if (generation != _generation) return;
        NSMutableArray *apps = [NSMutableArray array];
        for (NSDictionary *app in json[@"data"]) {
            RSAppSummary *summary = [RSAppSummary summaryWithApp:app];
            if (summary) [apps addObject:summary];
        }
        [self showCards:apps];
        if (error)
            [self showStatus:[NSString stringWithFormat:@"Kan LegacyStore niet bereiken.\n%@", error.localizedDescription] loading:NO];
        else
            [self showStatus:apps.count ? nil : @"Niets gevonden in het archief." loading:NO];
    }];
}

- (void)showCards:(NSArray *)apps {
    [_cards makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSMutableArray *cards = [NSMutableArray array];
    CGFloat height = _pager.bounds.size.height - 14;
    CGFloat inset = round((RSCardPitch - RSCardWidth) / 2);
    for (NSUInteger i = 0; i < apps.count; i++) {
        RSSearchCard *card = [[RSSearchCard alloc] initWithFrame:CGRectMake(i * RSCardPitch + inset, 12, RSCardWidth, height)
                                                             app:apps[i]];
        [card addTarget:self action:@selector(cardTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_pager addSubview:card];
        [cards addObject:card];
    }
    _cards = cards;
    _pager.contentSize = CGSizeMake(apps.count * RSCardPitch, _pager.bounds.size.height);
    _pager.contentOffset = CGPointZero;
    [self pageChanged];
}

- (void)refreshButtons {
    [_cards makeObjectsPerformSelector:@selector(refreshButton)];
}

- (void)cardTapped:(RSSearchCard *)card {
    RSAppDetailViewController *detail = [[RSAppDetailViewController alloc] initWithSummary:card.app];
    [self.navigationController pushViewController:detail animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self pageChanged];
}

- (void)pageChanged {
    if (!_cards.count) {
        _pageLabel.text = nil;
        return;
    }
    NSInteger page = MAX(0, MIN((NSInteger)_cards.count - 1, (NSInteger)round(_pager.contentOffset.x / RSCardPitch)));
    _pageLabel.text = [NSString stringWithFormat:@"%ld van %lu", (long)page + 1, (unsigned long)_cards.count];
    for (NSInteger i = page - 1; i <= page + 1; i++)
        if (i >= 0 && i < (NSInteger)_cards.count) [_cards[i] loadDetails];
}

@end
