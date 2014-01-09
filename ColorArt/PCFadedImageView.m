//
//  PCFadedImageView.m
//  ColorArt
//
//
// Copyright (C) 2012 Panic Inc. Code by Wade Cosgrove. All rights reserved.
//
// Redistribution and use, with or without modification, are permitted provided that the following conditions are met:
//
// - Redistributions must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//
// - Neither the name of Panic Inc nor the names of its contributors may be used to endorse or promote works derived from this software without specific prior written permission from Panic Inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PANIC INC BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import "PCFadedImageView.h"

@implementation PCFadedImageView
#if TARGET_OS_IPHONE
{
    CAGradientLayer *_gradientLayer;
}
#endif

//@synthesize image = _image;
- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
#if TARGET_OS_IPHONE
    [_gradientLayer removeFromSuperlayer];
    _gradientLayer = nil;
#endif
}

#if TARGET_OS_IPHONE
- (void)drawRect:(CGRect)rect
#else
- (void)drawRect:(NSRect)dirtyRect
#endif
{

#if TARGET_OS_IPHONE
    CGSize imageSize;
    CGRect bounds;
    CGRect imageRect;
    CGRect (*MakeRect)(CGFloat, CGFloat, CGFloat, CGFloat) = CGRectMake;
#else
    NSSize imageSize;
    NSRect bounds;
    NSRect imageRect;
    NSRect (*MakeRect)(CGFloat, CGFloat, CGFloat, CGFloat) = NSMakeRect;
#endif
    imageSize = [self.image size];
    bounds = self.bounds;
    imageRect = MakeRect(bounds.size.width - imageSize.width, bounds.size.height - imageSize.height, imageSize.width * 1.6, imageSize.height*1.6);


#if TARGET_OS_IPHONE
//    [self.image drawInRect:self.bounds];
    [self.image drawInRect:imageRect];
#else
	[self.image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
#endif

	// lazy way to get fade color
#if TARGET_OS_IPHONE
	UIColor *backgroundColor = [self backgroundColor];
    if (!backgroundColor) return;
#else
	NSColor *backgroundColor = [[self window] backgroundColor];
#endif

#if TARGET_OS_IPHONE
    if (_gradientLayer == nil) {
        _gradientLayer = [CAGradientLayer layer];
        CAGradientLayer* gradient = [CAGradientLayer layer];
        gradient.frame = ({
            CGRect frame = self.bounds;
            frame.size.height *= 0.8;
            frame;
        });
        gradient.colors = [NSArray arrayWithObjects:
                           (id)[backgroundColor CGColor], //開始色
                           (id)[backgroundColor CGColor],
                           (id)[[backgroundColor colorWithAlphaComponent:0.01] CGColor], //終了色
                           nil];
        [gradient setStartPoint:CGPointMake(0.5, 0.0)];
        [gradient setEndPoint:CGPointMake(0.5, 1.0)]; // 0 degree
        [self.layer addSublayer:gradient];
        _gradientLayer = gradient;
    }
#else

	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:backgroundColor, 0.0, backgroundColor, .01, [backgroundColor colorWithAlphaComponent:0.05], 1.0, nil];

	[gradient drawInRect:imageRect angle:0.0];

#endif
}


@end