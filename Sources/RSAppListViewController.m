#import "RSAppListViewController.h"
#import "RSAppCell.h"
#import "RSAppDetailViewController.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"

UIView *RSStatusView(CGFloat width, NSString *text, BOOL loading) {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 120)];
    view.backgroundColor = [UIColor clearColor];
    UILabel *label = RSLabel([UIFont systemFontOfSize:15], [RSTheme secondaryTextColor]);
    label.frame = CGRectMake(20, loading ? 50 : 0, width - 40, loading ? 24 : 120);
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.text = text;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(0, 1);
    [view addSubview:label];
    if (loading) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinner.center = CGPointMake(width / 2, 30);
        spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [spinner startAnimating];
        [view addSubview:spinner];
    }
    return view;
}

@implementation RSAppListViewController {
    NSUInteger _generation;
}

- (instancetype)initWithTitle:(NSString *)title loader:(RSAppListLoader)loader {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        self.title = title;
        _loader = [loader copy];
        _emptyText = @"Geen apps gevonden.";
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        for (NSString *name in @[RSInstallerDidChangeNotification, RSInstalledAppsDidChangeNotification, RSGenresDidLoadNotification])
            [center addObserver:self selector:@selector(refreshRows) name:name object:nil];
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
    _tableView.rowHeight = [RSAppCell height];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [view addSubview:_tableView];
    self.view = view;
    [self layoutTopBar];
    if (_headerText) {
        CGFloat width = view.bounds.size.width;
        UIFont *font = [UIFont systemFontOfSize:13];
        CGSize size = [_headerText sizeWithFont:font constrainedToSize:CGSizeMake(width - 32, 200)];
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, size.height + 22)];
        UILabel *label = RSLabel(font, [RSTheme secondaryTextColor]);
        label.frame = CGRectMake(16, 11, width - 32, size.height);
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.text = _headerText;
        label.shadowColor = [UIColor whiteColor];
        label.shadowOffset = CGSizeMake(0, 1);
        [header addSubview:label];
        UIView *line = [RSTheme engravedLineWithWidth:width];
        line.frame = (CGRect){CGPointMake(0, header.bounds.size.height - line.bounds.size.height), line.bounds.size};
        [header addSubview:line];
        _tableView.tableHeaderView = header;
    }
}

- (void)setTopBar:(UIView *)topBar {
    [_topBar removeFromSuperview];
    _topBar = topBar;
    if (self.isViewLoaded) [self layoutTopBar];
}

- (void)layoutTopBar {
    CGRect bounds = self.view.bounds;
    CGFloat top = 0;
    if (_topBar) {
        _topBar.frame = CGRectMake(0, 0, bounds.size.width, _topBar.bounds.size.height);
        _topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.view addSubview:_topBar];
        top = _topBar.bounds.size.height;
    }
    _tableView.frame = CGRectMake(0, top, bounds.size.width, bounds.size.height - top);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.loader) [self reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSIndexPath *selected = _tableView.indexPathForSelectedRow;
    if (selected) [_tableView deselectRowAtIndexPath:selected animated:animated];
}

- (void)refreshRows {
    if (self.isViewLoaded) [_tableView reloadData];
}

- (void)reload {
    if (!self.loader) return;
    NSUInteger generation = ++_generation;
    self.apps = @[];
    [self showStatus:@"Laden…" loading:YES];
    __weak RSAppListViewController *weakSelf = self;
    self.loader(self, ^(NSArray *apps, NSError *error) {
        RSAppListViewController *controller = weakSelf;
        if (!controller || generation != controller->_generation) return;
        controller.apps = apps ?: @[];
        if (error)
            [controller showStatus:[NSString stringWithFormat:@"Kan LegacyStore niet bereiken.\n%@", error.localizedDescription] loading:NO];
        else
            [controller showStatus:apps.count ? nil : controller.emptyText loading:NO];
    });
}

- (void)setApps:(NSArray *)apps {
    _apps = [apps copy];
    [_tableView reloadData];
    if (_apps.count) [_tableView setContentOffset:CGPointZero animated:NO];
}

- (void)showStatus:(NSString *)text loading:(BOOL)loading {
    _tableView.tableFooterView = (text || loading) ? RSStatusView(_tableView.bounds.size.width, text, loading) : [UIView new];
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.apps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSAppCell *cell = [tableView dequeueReusableCellWithIdentifier:@"app"];
    if (!cell) cell = [[RSAppCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"app"];
    [cell configureWithSummary:self.apps[indexPath.row] showRank:self.showsRank dark:indexPath.row % 2];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    RSAppDetailViewController *detail = [[RSAppDetailViewController alloc] initWithSummary:self.apps[indexPath.row]];
    [self.navigationController pushViewController:detail animated:YES];
}

@end
