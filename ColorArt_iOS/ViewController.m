//
//  ViewController.m
//  ColorArt
//
//  Created by 林 達也 on 2014/01/09.
//  Copyright (c) 2014年 Wade Cosgrove. All rights reserved.
//

#import "ViewController.h"
#import "SLColorArt.h"
#import "PCFadedImageView.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *primaryLabel;
@property (weak, nonatomic) IBOutlet UILabel *secondaryLabel;
@property (weak, nonatomic) IBOutlet UILabel *detailLabel;
@property (weak, nonatomic) PCFadedImageView *imageView;
@end

@implementation ViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    PCFadedImageView *imageView = [[PCFadedImageView alloc] init];
    imageView.frame = self.view.bounds;
    [self.view insertSubview:imageView atIndex:0];

    self.imageView = imageView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    NSLog(@"Begin %@", [NSDate date]);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [UIImage imageNamed:@"SampleImage"];
        SLColorArt *color = [[SLColorArt alloc] initWithImage:image scaledSize:CGSizeMake(320, 320)];
        NSLog(@"End %@", [NSDate date]);
        NSLog(@"backgroundColor: %@", color.backgroundColor);
        NSLog(@"primaryColor: %@", color.primaryColor);
        NSLog(@"secondaryColor: %@", color.secondaryColor);
        NSLog(@"detailColor: %@", color.detailColor);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = color.scaledImage;
            self.imageView.backgroundColor = color.backgroundColor;
            self.primaryLabel.textColor = color.primaryColor;
            self.secondaryLabel.textColor = color.secondaryColor;
            self.detailLabel.textColor = color.detailColor;
        });
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
