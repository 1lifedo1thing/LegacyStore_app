#import "RSAppListViewController.h"

RSAppListLoader RSCompatibleAppsLoader(void);
RSAppListLoader RSCollectionLoader(NSString *slug);
RSAppListLoader RSGenreLoader(NSString *genreID);
RSAppListLoader RSChartLoader(NSString *type, NSString *date, NSUInteger limit);
