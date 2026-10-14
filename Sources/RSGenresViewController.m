#import "RSGenresViewController.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"

@implementation RSGenresViewController {
    NSString *_allTitle;
    RSGenreSelection _selection;
    NSArray *_genres;
}

- (instancetype)initWithAllTitle:(NSString *)allTitle selection:(RSGenreSelection)selection {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"Categorieën";
        _allTitle = [allTitle copy];
        _selection = [selection copy];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(genresLoaded)
                                                     name:RSGenresDidLoadNotification object:nil];
        [self genresLoaded];
        [RSGenres loadGenres];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)genresLoaded {
    NSMutableArray *genres = [NSMutableArray array];
    for (NSDictionary *genre in [RSGenres all])
        if ([genre[@"app_count"] integerValue] > 0) [genres addObject:genre];
    _genres = genres;
    if (self.isViewLoaded) [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [RSTheme backgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 46;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _genres.count + (_allTitle ? 1 : 0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"genre"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"genre"];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
        cell.textLabel.textColor = [RSTheme textColor];
        cell.textLabel.shadowColor = [UIColor whiteColor];
        cell.textLabel.shadowOffset = CGSizeMake(0, 1);
        cell.textLabel.backgroundColor = cell.detailTextLabel.backgroundColor = [UIColor clearColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.selectedBackgroundView = [RSTheme rowBackgroundDark:NO selected:YES];
    }
    cell.backgroundView = [RSTheme rowBackgroundDark:indexPath.row % 2 selected:NO];
    NSInteger row = indexPath.row - (_allTitle ? 1 : 0);
    NSDictionary *genre = row >= 0 ? _genres[row] : nil;
    cell.textLabel.text = genre ? genre[@"name"] : _allTitle;
    cell.detailTextLabel.text = genre ? [NSString stringWithFormat:@"%@", genre[@"app_count"]] : nil;
    BOOL selected = [RSString(genre[@"genre_id"]) isEqualToString:_selectedGenreID] || (!genre && !_selectedGenreID);
    cell.accessoryType = selected && _allTitle ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger row = indexPath.row - (_allTitle ? 1 : 0);
    NSDictionary *genre = row >= 0 ? _genres[row] : nil;
    _selection(RSString(genre[@"genre_id"]), genre[@"name"]);
}

@end
