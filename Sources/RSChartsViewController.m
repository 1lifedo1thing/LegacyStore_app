#import "RSChartsViewController.h"
#import "RSAPI.h"
#import "RSGenresViewController.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"

static NSString *const RSChartYearKey = @"RSChartYear";

@interface RSChartsViewController () <UIActionSheetDelegate>
@end

@implementation RSChartsViewController {
    UISegmentedControl *_typeControl;
    NSInteger _year;
    NSString *_genreID, *_genreName;
}

+ (NSArray *)chartTypes {
    return @[@"top-paid", @"top-free", @"top-grossing"];
}

+ (NSArray *)years {
    return @[@2008, @2009, @2010, @2011, @2012, @2013];
}

- (instancetype)init {
    self = [super initWithTitle:@"Toplijsten" loader:^(RSAppListViewController *controller, RSAppListDone done) {
        [(RSChartsViewController *)controller loadChart:done];
    }];
    if (self) {
        self.showsRank = YES;
        _year = [[NSUserDefaults standardUserDefaults] integerForKey:RSChartYearKey] ?: 2012;
    }
    return self;
}

- (void)viewDidLoad {
    _typeControl = [[UISegmentedControl alloc] initWithItems:@[@"Top betaald", @"Top gratis", @"Top verdieners"]];
    _typeControl.segmentedControlStyle = UISegmentedControlStyleBar;
    _typeControl.selectedSegmentIndex = 1;
    [_typeControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    self.topBar = [RSTheme segmentBarWithControl:_typeControl width:self.view.bounds.size.width];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Categorieën"
        style:UIBarButtonItemStyleBordered target:self action:@selector(pickGenre)];
    [self updateYearButton];
    [super viewDidLoad];
}

- (void)updateYearButton {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:[NSString stringWithFormat:@"%ld", (long)_year] style:UIBarButtonItemStyleBordered
               target:self action:@selector(pickYear)];
}

- (void)pickGenre {
    __weak RSChartsViewController *weakSelf = self;
    RSGenresViewController *genres = [[RSGenresViewController alloc] initWithAllTitle:@"Alle categorieën"
        selection:^(NSString *genreID, NSString *name) {
        RSChartsViewController *charts = weakSelf;
        charts->_genreID = genreID;
        charts->_genreName = name;
        charts.navigationItem.title = name ?: @"Toplijsten";
        [charts.navigationController popToViewController:charts animated:YES];
        [charts reload];
    }];
    genres.selectedGenreID = _genreID;
    [self.navigationController pushViewController:genres animated:YES];
}

- (void)pickYear {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Toplijst uit welk jaar?" delegate:self
        cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    for (NSNumber *year in [[self class] years]) [sheet addButtonWithTitle:year.stringValue];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Annuleer"];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [sheet showFromTabBar:self.tabBarController.tabBar];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == sheet.cancelButtonIndex) return;
    _year = [[[self class] years][index] integerValue];
    [[NSUserDefaults standardUserDefaults] setInteger:_year forKey:RSChartYearKey];
    [self updateYearButton];
    [self reload];
}

- (void)loadChart:(RSAppListDone)done {
    NSInteger typeIndex = _typeControl ? _typeControl.selectedSegmentIndex : 1;
    NSString *date = _year == 2008 ? @"2008-09-15" : [NSString stringWithFormat:@"%ld-06-15", (long)_year];
    NSMutableDictionary *query = [@{@"type": [[self class] chartTypes][typeIndex], @"date": date, @"device": @"iphone"} mutableCopy];
    if (_genreID) query[@"genre"] = _genreID;
    NSString *genreID = _genreID;
    [RSAPI getPath:@"/api/v1/charts" query:query completion:^(NSDictionary *json, NSError *error) {
        NSMutableArray *apps = [NSMutableArray array];
        for (NSDictionary *position in json[@"positions"]) {
            RSAppSummary *summary = [RSAppSummary summaryWithChartPosition:position];
            if (!summary) continue;
            if (!summary.genreID) summary.genreID = genreID;
            [apps addObject:summary];
        }
        NSString *snapshot = RSFormatDate(RSString(json[@"snapshot_date"]));
        self.tableView.tableHeaderView = snapshot ? [self headerWithText:
            [NSString stringWithFormat:@"Zo zag de toplijst eruit op %@", snapshot]] : nil;
        done(apps, error);
    }];
}

- (UIView *)headerWithText:(NSString *)text {
    UILabel *label = RSLabel([UIFont boldSystemFontOfSize:12], [RSTheme secondaryTextColor]);
    label.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 26);
    label.text = text;
    label.textAlignment = NSTextAlignmentCenter;
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(0, 1);
    return label;
}

@end
