#import "RSVersionsViewController.h"
#import "RSAppListViewController.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"

@interface RSVersionsViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation RSVersionsViewController {
    NSDictionary *_app;
    NSArray *_installables;
    NSInteger _confirmRow;
    UITableView *_tableView;
}

- (instancetype)initWithApp:(NSDictionary *)app {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _app = app;
        _installables = [RSInstallable installablesForApp:app];
        _confirmRow = -1;
        self.title = @"Versies";
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        for (NSString *name in @[RSInstallerDidChangeNotification, RSInstalledAppsDidChangeNotification])
            [center addObserver:self selector:@selector(refresh) name:name object:nil];
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
    _tableView.rowHeight = 62;
    _tableView.allowsSelection = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    NSString *footer = _installables.count ?
        [NSString stringWithFormat:@"Alleen versies die op iOS %@ werken worden getoond.", RSSystemVersion()] :
        [NSString stringWithFormat:@"Geen versie in het archief werkt op iOS %@.", RSSystemVersion()];
    _tableView.tableFooterView = RSStatusView(view.bounds.size.width, footer, NO);
    [view addSubview:_tableView];
    self.view = view;
}

- (void)refresh {
    _confirmRow = -1;
    [_tableView reloadData];
}

- (NSString *)bundleID {
    return RSString(_app[@"bundle_id"]);
}

- (RSPriceState)stateForRow:(NSInteger)row {
    if (row == _confirmRow) return RSPriceStateConfirm;
    RSInstallable *installable = _installables[row];
    NSString *installed = RSInstalledVersion([self bundleID]);
    if ([RSInstaller isInstalling:RSString(_app[@"app_store_id"])]) return RSPriceStateInstalling;
    if (installed && [installed isEqualToString:installable.version]) return RSPriceStateOpen;
    return RSPriceStateInstall;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _installables.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"version"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"version"];
        CGFloat width = tableView.bounds.size.width;
        UILabel *title = RSLabel([UIFont boldSystemFontOfSize:16], [RSTheme textColor]);
        title.frame = CGRectMake(14, 11, width - 130, 20);
        title.tag = 1;
        UILabel *detail = RSLabel([UIFont systemFontOfSize:12], [RSTheme secondaryTextColor]);
        detail.frame = CGRectMake(14, 33, width - 130, 16);
        detail.tag = 2;
        for (UILabel *label in @[title, detail]) {
            label.shadowColor = [UIColor whiteColor];
            label.shadowOffset = CGSizeMake(0, 1);
            [cell.contentView addSubview:label];
        }
        RSPriceButton *button = [RSPriceButton buttonWithRightEdge:width - 10 y:18];
        button.tag = 3;
        [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:button];
    }
    RSInstallable *installable = _installables[indexPath.row];
    cell.backgroundView = [RSTheme rowBackgroundDark:indexPath.row % 2 selected:NO];
    ((UILabel *)[cell.contentView viewWithTag:1]).text = [@"Versie " stringByAppendingString:installable.version];
    NSMutableArray *parts = [NSMutableArray array];
    if (RSFormatDate(installable.releaseDate)) [parts addObject:RSFormatDate(installable.releaseDate)];
    if (installable.size > 0) [parts addObject:RSFormatBytes(installable.size)];
    if (installable.minimumOS) [parts addObject:[@"iOS " stringByAppendingFormat:@"%@+", installable.minimumOS]];
    ((UILabel *)[cell.contentView viewWithTag:2]).text = [parts componentsJoinedByString:@" · "];
    RSPriceButton *button = (RSPriceButton *)[cell.contentView viewWithTag:3];
    button.priceState = [self stateForRow:indexPath.row];
    return cell;
}

- (void)buttonTapped:(RSPriceButton *)button {
    CGPoint point = [button convertPoint:CGPointMake(1, 1) toView:_tableView];
    NSInteger row = [_tableView indexPathForRowAtPoint:point].row;
    if (row < 0 || row >= (NSInteger)_installables.count) return;
    switch (button.priceState) {
        case RSPriceStateOpen:
            [RSInstaller open:[self bundleID]];
            break;
        case RSPriceStateConfirm:
            _confirmRow = -1;
            if ([RSInstaller install:_installables[row] ofApp:_app])
                [button setPriceState:RSPriceStateInstalling animated:YES];
            else
                [_tableView reloadData];
            break;
        case RSPriceStateInstalling:
            break;
        default:
            _confirmRow = row;
            [_tableView reloadData];
    }
}

@end
