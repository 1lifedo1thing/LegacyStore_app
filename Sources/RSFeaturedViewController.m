#import "RSFeaturedViewController.h"
#import "RSAPI.h"
#import "RSAppDetailViewController.h"
#import "RSFeeds.h"
#import "RSGenresViewController.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSShelfCell.h"
#import "RSTheme.h"
#import "RSUtil.h"

@implementation RSFeaturedViewController {
    NSMutableArray *_shelves;
    NSString *_status;
}

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"Uitgelicht";
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        for (NSString *name in @[RSInstallerDidChangeNotification, RSInstalledAppsDidChangeNotification, RSGenresDidLoadNotification])
            [center addObserver:self selector:@selector(refresh) name:name object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [RSTheme backgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = [RSShelfCell height];
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 6)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Categorieën"
        style:UIBarButtonItemStyleBordered target:self action:@selector(showCategories)];

    _shelves = [NSMutableArray array];
    [self addShelf:@"Werkt op deze iPhone" loader:RSCompatibleAppsLoader()];
    [self addShelf:@"Populair in 2012" loader:RSChartLoader(@"top-free", @"2012-06-15", 25)];
    [self addShelf:@"Topverdieners 2010" loader:RSChartLoader(@"top-grossing", @"2010-06-15", 25)];
    [self loadCollections];
}

- (void)refresh {
    if (self.isViewLoaded) [self.tableView reloadData];
}

- (void)addShelf:(NSString *)title loader:(RSAppListLoader)loader {
    NSMutableDictionary *shelf = [@{@"title": title, @"loader": [loader copy]} mutableCopy];
    [_shelves addObject:shelf];
    __weak RSFeaturedViewController *weakSelf = self;
    loader(nil, ^(NSArray *apps, NSError *error) {
        RSFeaturedViewController *controller = weakSelf;
        if (!controller) return;
        if (apps.count) {
            shelf[@"apps"] = apps;
        } else {
            [controller->_shelves removeObject:shelf];
        }
        [controller.tableView reloadData];
    });
    [self.tableView reloadData];
}

- (void)loadCollections {
    [RSAPI getPath:@"/api/v1/collections" query:nil completion:^(NSDictionary *json, NSError *error) {
        NSArray *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
        if (error) {
            _status = [NSString stringWithFormat:@"Kan LegacyStore niet bereiken.\n%@", error.localizedDescription];
            self.tableView.tableFooterView = RSStatusView(self.tableView.bounds.size.width, _status, NO);
            return;
        }
        for (NSDictionary *collection in data) {
            NSString *slug = RSString(collection[@"slug"]), *title = RSString(collection[@"title"]);
            if (slug && title && [collection[@"app_count"] integerValue] >= 3)
                [self addShelf:title loader:RSCollectionLoader(slug)];
        }
    }];
}

- (void)showCategories {
    __weak RSFeaturedViewController *weakSelf = self;
    RSGenresViewController *genres = [[RSGenresViewController alloc] initWithAllTitle:nil
        selection:^(NSString *genreID, NSString *name) {
        RSAppListViewController *list = [[RSAppListViewController alloc] initWithTitle:name loader:RSGenreLoader(genreID)];
        [weakSelf.navigationController pushViewController:list animated:YES];
    }];
    [self.navigationController pushViewController:genres animated:YES];
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _shelves.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RSShelfCell *cell = [tableView dequeueReusableCellWithIdentifier:@"shelf"];
    if (!cell) cell = [[RSShelfCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"shelf"];
    NSDictionary *shelf = _shelves[indexPath.row];
    [cell configureWithTitle:shelf[@"title"] apps:shelf[@"apps"]];
    __weak RSFeaturedViewController *weakSelf = self;
    cell.onSelectApp = ^(RSAppSummary *app) {
        RSAppDetailViewController *detail = [[RSAppDetailViewController alloc] initWithSummary:app];
        [weakSelf.navigationController pushViewController:detail animated:YES];
    };
    cell.onSeeAll = ^{
        RSAppListViewController *list = [[RSAppListViewController alloc] initWithTitle:shelf[@"title"] loader:nil];
        list.apps = shelf[@"apps"];
        [weakSelf.navigationController pushViewController:list animated:YES];
    };
    return cell;
}

@end
