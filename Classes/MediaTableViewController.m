// Copyright 2014 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "AppDelegate.h"
#import "CastDeviceController.h"
#import "LocalPlayerViewController.h"
#import "Media.h"
#import "MediaListModel.h"
#import "MediaTableViewController.h"
#import "SimpleImageFetcher.h"

#import <GoogleCast/GCKDeviceManager.h>

@interface MediaTableViewController () <CastDeviceControllerDelegate>

/** The media to be displayed. */
@property(nonatomic, strong) MediaListModel *mediaList;

/** The queue button. */
@property(nonatomic, strong) UIBarButtonItem *showQueueButton;

@end

@implementation MediaTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Show stylized application title as a left-aligned image.
  UIView *titleView =
      [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo_castvideos.png"]];
  self.navigationItem.titleView = [[UIView alloc] init];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:titleView];

  // Asynchronously load the media json.
  AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
  delegate.mediaList = [[MediaListModel alloc] init];
  self.mediaList = delegate.mediaList;
  [self.mediaList loadMedia:^{
    self.title = self.mediaList.mediaTitle;
    [self.tableView reloadData];
  }];

  // Create the queue button.
  UIImage *playlistImage = [UIImage imageNamed:@"playlist_white.png"];
  _showQueueButton = [[UIBarButtonItem alloc] initWithImage:playlistImage
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(showQueue:)];

  GCKDeviceManager *manager = [CastDeviceController sharedInstance].deviceManager;
  _showQueueButton.enabled = (manager.applicationConnectionState == GCKConnectionStateConnected);
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // Assign ourselves as delegate ONLY in viewWillAppear of a view controller.
  CastDeviceController *controller = [CastDeviceController sharedInstance];
  controller.delegate = self;

  UIBarButtonItem *item = [controller queueItemForController:self];
  self.navigationItem.rightBarButtonItems = @[item, _showQueueButton];
}

#pragma mark - CastDeviceControllerDelegate

- (void)didConnectToDevice:(GCKDevice *)device {
  _showQueueButton.enabled = YES;
}

- (void)didDisconnect {
  _showQueueButton.enabled = NO;
}

#pragma mark - Interface

- (void)showQueue:(id)sender {
  [self performSegueWithIdentifier:@"showQueue" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"playMedia"]) {
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    Media *media = [self.mediaList mediaAtIndex:(int)indexPath.row];
    // Pass the currently selected media to the next controller if it needs it.
    [[segue destinationViewController] setMediaToPlay:media];
  }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [self.mediaList numberOfMediaLoaded];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
  Media *media = [self.mediaList mediaAtIndex:(int)indexPath.row];

  UILabel *mediaTitle = (UILabel *)[cell viewWithTag:1];
  mediaTitle.text = media.title;

  UILabel *mediaOwner = (UILabel *)[cell viewWithTag:2];
  mediaOwner.text = media.subtitle;

  // Asynchronously load the table view image
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

  dispatch_async(queue, ^{
    UIImage *image =
        [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL:media.thumbnailURL]];

    dispatch_sync(dispatch_get_main_queue(), ^{
      UIImageView *mediaThumb = (UIImageView *)[cell viewWithTag:3];
      [mediaThumb setImage:image];
      [cell setNeedsLayout];
    });
  });

  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  // Display the media details view.
  [self performSegueWithIdentifier:@"playMedia" sender:self];
}

@end