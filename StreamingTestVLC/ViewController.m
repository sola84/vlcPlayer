//
//  ViewController.m
//  StreamingTestVLC
//
//  Created by Shin Chang Keun on 2018. 3. 26..
//  Copyright © 2018년 kokoro. All rights reserved.
//

#import "ViewController.h"
#import "VideoListTableViewCell.h"

#define VIDEOLIST_ROW_HEIGHT 60.0f

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *mTblVideoList;
@property (strong, nonatomic) NSMutableArray *mEntryVideoList;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _mTblVideoList.delegate = self;
    _mTblVideoList.dataSource = self;
    
    [self addVideoEntryData];
    
    [_mTblVideoList reloadData];
}

- (void) addVideoEntryData {
    
    _mEntryVideoList = @[@{ @"videoName" : @"EVT_2012_07_27_17_58_20_F", @"videoUrl" : @"rtsp://52.79.169.203/vod/_definst_/mp4:/blackbox/upload/record/20180220/EVT_2012_07_27_17_58_20_F.MP4", @"videoType" : @"F" },
                         @{ @"videoName" : @"EVT_2012_07_27_17_58_20_R", @"videoUrl" : @"rtsp://52.79.169.203/vod/_definst_/mp4:/blackbox/upload/record/20180220/EVT_2012_07_27_17_58_20_F.MP4", @"videoType" : @"R" },
                         @{ @"videoName" : @"EVT_2012_07_27_17_57_20_F", @"videoUrl" : @"rtsp://52.79.169.203/vod/_definst_/mp4:/blackbox/upload/record/20180220/EVT_2012_07_27_17_58_20_F.MP4", @"videoType" : @"F" },
                         @{ @"videoName" : @"EVT_2012_07_27_17_57_20_R", @"videoUrl" : @"rtsp://52.79.169.203/vod/_definst_/mp4:/blackbox/upload/record/20180220/EVT_2012_07_27_17_58_20_F.MP4", @"videoType" : @"R" }];
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableView Delegate.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    /// 섹션 개수
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _mEntryVideoList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return VIDEOLIST_ROW_HEIGHT;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"VideoListTableViewCell";
    
    VideoListTableViewCell *cell = (VideoListTableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    cell.mLabVideoName.text = [[_mEntryVideoList objectAtIndex:indexPath.row] objectForKey:@"videoName"];
    
    return cell;
}

- (void)tableView:(UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
//    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Record" bundle:nil];
//    TWRecordFilePlayerViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"TWRecordFilePlayerViewController"];
//    viewController.file = file;
//    viewController.playType = 0;
//    viewController.delegate = self;
//    [self presentViewController:viewController animated:YES completion:NULL];
    
}


@end
