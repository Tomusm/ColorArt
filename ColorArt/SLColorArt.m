//
//  SLColorArt.m
//  ColorArt
//
//  Created by Aaron Brethorst on 12/11/12.
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


#import "SLColorArt.h"

#define kColorThresholdMinimumPercentage 0.01

#if TARGET_OS_IPHONE
@interface UIColor (DarkAddition)
#else
@interface NSColor (DarkAddition)
#endif

- (BOOL)pc_isDarkColor;
- (BOOL)pc_isDistinct:(NSUIColor*)compareColor;
- (NSUIColor*)pc_colorWithMinimumSaturation:(CGFloat)saturation;
- (BOOL)pc_isBlackOrWhite;
- (BOOL)pc_isContrastingColor:(NSUIColor*)color;

@end


@interface PCCountedColor : NSObject

@property (assign) NSUInteger count;
@property (strong) NSUIColor *color;

- (id)initWithColor:(NSUIColor*)color count:(NSUInteger)count;

@end


@interface SLColorArt ()

@property NSCGSize scaledSize;
@property(retain,readwrite) NSUIColor *backgroundColor;
@property(retain,readwrite) NSUIColor *primaryColor;
@property(retain,readwrite) NSUIColor *secondaryColor;
@property(retain,readwrite) NSUIColor *detailColor;
@end


@implementation SLColorArt

- (id)initWithImage:(NSUIImage*)image scaledSize:(NSCGSize)size
{
    self = [super init];

    if (self)
    {
        self.scaledSize = size;
		
		NSUIImage *finalImage = [self scaleImage:image size:size];
		self.scaledImage = finalImage;
		
		[self analyzeImage:image];
    }

    return self;
}


- (NSUIImage*)scaleImage:(NSUIImage*)image size:(NSCGSize)scaledSize
{
    NSCGSize imageSize = [image size];
#if TARGET_OS_IPHONE
    UIImage *squareImage, *scaledImage;
    CGRect drawRect;
    CGRect (*MakeRect)(CGFloat, CGFloat, CGFloat, CGFloat) = CGRectMake;
#else
    NSUIImage *squareImage = [[NSImage alloc] initWithSize:NSMakeSize(imageSize.width, imageSize.width)];
    NSUIImage *scaledImage = [[NSImage alloc] initWithSize:scaledSize];
    NSRect drawRect;
    NSRect (*MakeRect)(CGFloat, CGFloat, CGFloat, CGFloat) = NSMakeRect;
#endif

    // make the image square
    if (imageSize.height > imageSize.width) {
        drawRect = MakeRect(0, imageSize.height - imageSize.width, imageSize.width, imageSize.width);
    } else {
        drawRect = MakeRect(0, 0, imageSize.height, imageSize.height);
    }

#if TARGET_OS_IPHONE
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageSize.width, imageSize.width), NO, 0.0);
    [image drawInRect:drawRect];
    squareImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();


    // scale the image to the desired size
    UIGraphicsBeginImageContextWithOptions(scaledSize, NO, 0.0);
    [squareImage drawInRect:MakeRect(0, 0, scaledSize.width, scaledSize.height)];
    scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIImage *finalImage = scaledImage;
#else
    [squareImage lockFocus];
    [image drawInRect:NSMakeRect(0, 0, imageSize.width, imageSize.width) fromRect:drawRect operation:NSCompositeSourceOver fraction:1.0];
    [squareImage unlockFocus];

    // scale the image to the desired size

    [scaledImage lockFocus];
    [squareImage drawInRect:NSMakeRect(0, 0, scaledSize.width, scaledSize.height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    [scaledImage unlockFocus];

    // convert back to readable bitmap data

    CGImageRef cgImage = [scaledImage CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSUIImage *finalImage = [[NSUIImage alloc] initWithSize:scaledImage.size];
    [finalImage addRepresentation:bitmapRep];
#endif
    return finalImage;
}

- (void)analyzeImage:(NSUIImage*)anImage
{
    NSCountedSet *imageColors = nil;
	NSUIColor *backgroundColor = [self findEdgeColor:anImage imageColors:&imageColors];
	NSUIColor *primaryColor = nil;
	NSUIColor *secondaryColor = nil;
	NSUIColor *detailColor = nil;
	BOOL darkBackground = [backgroundColor pc_isDarkColor];

	[self findTextColors:imageColors primaryColor:&primaryColor secondaryColor:&secondaryColor detailColor:&detailColor backgroundColor:backgroundColor];

	if ( primaryColor == nil )
	{
		NSLog(@"missed primary");
		if ( darkBackground )
			primaryColor = [NSUIColor whiteColor];
		else
			primaryColor = [NSUIColor blackColor];
	}

	if ( secondaryColor == nil )
	{
		NSLog(@"missed secondary");
		if ( darkBackground )
			secondaryColor = [NSUIColor whiteColor];
		else
			secondaryColor = [NSUIColor blackColor];
	}

	if ( detailColor == nil )
	{
		NSLog(@"missed detail");
		if ( darkBackground )
			detailColor = [NSUIColor whiteColor];
		else
			detailColor = [NSUIColor blackColor];
	}

    self.backgroundColor = backgroundColor;
    self.primaryColor = primaryColor;
	self.secondaryColor = secondaryColor;
    self.detailColor = detailColor;
}

- (NSUIColor*)findEdgeColor:(NSUIImage*)image imageColors:(NSCountedSet**)colors
{
#if TARGET_OS_IPHONE
    if (! image ) {
        return nil;
    }
    CFMutableDataRef inputData = ({
        CGDataProviderRef provider = CGImageGetDataProvider(image.CGImage);
        CFDataRef data = CGDataProviderCopyData(provider);
        
        CFMutableDataRef mutableData =  CFDataCreateMutableCopy(0, 0, data);
        CFRelease(data);
        mutableData;
    });

    size_t bits = ({
        size_t bpp = CGImageGetBitsPerPixel(image.CGImage);
        size_t bpc = CGImageGetBitsPerComponent(image.CGImage);
        bpp / bpc;
    });
    size_t pixelsWide = CGImageGetWidth(image.CGImage);
    size_t pixelsHigh = CGImageGetHeight(image.CGImage);

    const UInt8 *data = CFDataGetBytePtr(inputData);
#else
    NSBitmapImageRep *imageRep = [[image representations] lastObject];

	if ( ![imageRep isKindOfClass:[NSBitmapImageRep class]] ) // sanity check
		return nil;

	NSInteger pixelsWide = [imageRep pixelsWide];
	NSInteger pixelsHigh = [imageRep pixelsHigh];
#endif

	NSCountedSet *imageColors = [[NSCountedSet alloc] initWithCapacity:pixelsWide * pixelsHigh];
	NSCountedSet *leftEdgeColors = [[NSCountedSet alloc] initWithCapacity:pixelsHigh];

	for ( NSUInteger x = 0; x < pixelsWide; x++ )
    {
		for ( NSUInteger y = 0; y < pixelsHigh; y++ )
        {
#if TARGET_OS_IPHONE
            int pixelsInfo = ((pixelsWide * y) + x) * bits;
            UInt8 red = data[pixelsInfo];
            UInt8 green = data[pixelsInfo + 1];
            UInt8 blue = data[pixelsInfo + 2];
            UInt8 alpha = 255;
            if (bits == 4) {
                alpha = data[pixelsInfo + 3];
            }
            UIColor *color = [UIColor colorWithRed:red/255.0f green:green/255.0f blue:blue/255.0f alpha:alpha/255.0f];
#else
            NSColor *color = [imageRep colorAtX:x y:y];
#endif
			if ( x == 0 )
			{
				[leftEdgeColors addObject:color];
			}

			[imageColors addObject:color];
		}
	}
#if TARGET_OS_IPHONE
    CFRelease(inputData);
#endif

	*colors = imageColors;


	NSEnumerator *enumerator = [leftEdgeColors objectEnumerator];
	NSUIColor *curColor = nil;
	NSMutableArray *sortedColors = [NSMutableArray arrayWithCapacity:[leftEdgeColors count]];

	while ( (curColor = [enumerator nextObject]) != nil )
	{
		NSUInteger colorCount = [leftEdgeColors countForObject:curColor];

        NSInteger randomColorsThreshold = (NSInteger)(pixelsHigh * kColorThresholdMinimumPercentage);
        
		if ( colorCount <= randomColorsThreshold ) // prevent using random colors, threshold based on input image height
			continue;

		PCCountedColor *container = [[PCCountedColor alloc] initWithColor:curColor count:colorCount];

		[sortedColors addObject:container];
	}

	[sortedColors sortUsingSelector:@selector(compare:)];


	PCCountedColor *proposedEdgeColor = nil;

	if ( [sortedColors count] > 0 )
	{
		proposedEdgeColor = [sortedColors objectAtIndex:0];

		if ( [proposedEdgeColor.color pc_isBlackOrWhite] ) // want to choose color over black/white so we keep looking
		{
			for ( NSInteger i = 1; i < [sortedColors count]; i++ )
			{
				PCCountedColor *nextProposedColor = [sortedColors objectAtIndex:i];

				if (((double)nextProposedColor.count / (double)proposedEdgeColor.count) > .3 ) // make sure the second choice color is 30% as common as the first choice
				{
					if ( ![nextProposedColor.color pc_isBlackOrWhite] )
					{
						proposedEdgeColor = nextProposedColor;
						break;
					}
				}
				else
				{
					// reached color threshold less than 40% of the original proposed edge color so bail
					break;
				}
			}
		}
	}

	return proposedEdgeColor.color;
}


- (void)findTextColors:(NSCountedSet*)colors primaryColor:(NSUIColor**)primaryColor secondaryColor:(NSUIColor**)secondaryColor detailColor:(NSUIColor**)detailColor backgroundColor:(NSUIColor*)backgroundColor
{
	NSEnumerator *enumerator = [colors objectEnumerator];
	NSUIColor *curColor = nil;
	NSMutableArray *sortedColors = [NSMutableArray arrayWithCapacity:[colors count]];
	BOOL findDarkTextColor = ![backgroundColor pc_isDarkColor];

	while ( (curColor = [enumerator nextObject]) != nil )
	{
		curColor = [curColor pc_colorWithMinimumSaturation:.15];

		if ( [curColor pc_isDarkColor] == findDarkTextColor )
		{
			NSUInteger colorCount = [colors countForObject:curColor];

			//if ( colorCount <= 2 ) // prevent using random colors, threshold should be based on input image size
			//	continue;

			PCCountedColor *container = [[PCCountedColor alloc] initWithColor:curColor count:colorCount];

			[sortedColors addObject:container];
		}
	}

	[sortedColors sortUsingSelector:@selector(compare:)];

	for ( PCCountedColor *curContainer in sortedColors )
	{
		curColor = curContainer.color;

		if ( *primaryColor == nil )
		{
			if ( [curColor pc_isContrastingColor:backgroundColor] )
				*primaryColor = curColor;
		}
		else if ( *secondaryColor == nil )
		{
			if ( ![*primaryColor pc_isDistinct:curColor] || ![curColor pc_isContrastingColor:backgroundColor] )
				continue;

			*secondaryColor = curColor;
		}
		else if ( *detailColor == nil )
		{
			if ( ![*secondaryColor pc_isDistinct:curColor] || ![*primaryColor pc_isDistinct:curColor] || ![curColor pc_isContrastingColor:backgroundColor] )
				continue;
            
			*detailColor = curColor;
			break;
		}
	}
}

@end


#if TARGET_OS_IPHONE
@implementation UIColor (DarkAddition)
#else
@implementation NSColor (DarkAddition)
#endif

- (BOOL)pc_isDarkColor
{
#if TARGET_OS_IPHONE
    UIColor *convertedColor = self;
#else
    NSColor *convertedColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
#endif
	CGFloat r, g, b, a;

	[convertedColor getRed:&r green:&g blue:&b alpha:&a];

	CGFloat lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;

	if ( lum < .5 )
	{
		return YES;
	}

	return NO;
}


- (BOOL)pc_isDistinct:(NSUIColor*)compareColor
{
#if TARGET_OS_IPHONE
    UIColor *convertedColor = self;
    UIColor *convertedCompareColor = compareColor;
#else
	NSColor *convertedColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor *convertedCompareColor = [compareColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
#endif
	CGFloat r, g, b, a;
	CGFloat r1, g1, b1, a1;

	[convertedColor getRed:&r green:&g blue:&b alpha:&a];
	[convertedCompareColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1];

	CGFloat threshold = .25; //.15

	if ( fabs(r - r1) > threshold ||
		fabs(g - g1) > threshold ||
		fabs(b - b1) > threshold ||
		fabs(a - a1) > threshold )
    {
        // check for grays, prevent multiple gray colors

        if ( fabs(r - g) < .03 && fabs(r - b) < .03 )
        {
            if ( fabs(r1 - g1) < .03 && fabs(r1 - b1) < .03 )
                return NO;
        }

        return YES;
    }

	return NO;
}


- (NSUIColor*)pc_colorWithMinimumSaturation:(CGFloat)minSaturation
{
#if TARGET_OS_IPHONE
    UIColor *tempColor = self;
#else
	NSColor *tempColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
#endif
	if ( tempColor != nil )
	{
		CGFloat hue = 0.0;
		CGFloat saturation = 0.0;
		CGFloat brightness = 0.0;
		CGFloat alpha = 0.0;

		[tempColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

		if ( saturation < minSaturation )
		{

#if TARGET_OS_IPHONE
            return [UIColor colorWithHue:hue saturation:minSaturation brightness:brightness alpha:alpha];
#else
            return [NSColor colorWithCalibratedHue:hue saturation:minSaturation brightness:brightness alpha:alpha];
#endif
		}
	}

	return self;
}


- (BOOL)pc_isBlackOrWhite
{
#if TARGET_OS_IPHONE
    UIColor *tempColor = self;
#else
	NSColor *tempColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
#endif

	if ( tempColor != nil )
	{
		CGFloat r, g, b, a;

		[tempColor getRed:&r green:&g blue:&b alpha:&a];

		if ( r > .91 && g > .91 && b > .91 )
			return YES; // white

		if ( r < .09 && g < .09 && b < .09 )
			return YES; // black
	}

	return NO;
}


- (BOOL)pc_isContrastingColor:(NSUIColor*)color
{
#if TARGET_OS_IPHONE
    UIColor *backgroundColor = self;
    UIColor *foregroundColor = color;
#else
	NSColor *backgroundColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor *foregroundColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
#endif

	if ( backgroundColor != nil && foregroundColor != nil )
	{
		CGFloat br, bg, bb, ba;
		CGFloat fr, fg, fb, fa;

		[backgroundColor getRed:&br green:&bg blue:&bb alpha:&ba];
		[foregroundColor getRed:&fr green:&fg blue:&fb alpha:&fa];

		CGFloat bLum = 0.2126 * br + 0.7152 * bg + 0.0722 * bb;
		CGFloat fLum = 0.2126 * fr + 0.7152 * fg + 0.0722 * fb;

		CGFloat contrast = 0.;

		if ( bLum > fLum )
			contrast = (bLum + 0.05) / (fLum + 0.05);
		else
			contrast = (fLum + 0.05) / (bLum + 0.05);

		//return contrast > 3.0; //3-4.5 W3C recommends 3:1 ratio, but that filters too many colors
		return contrast > 1.6;
	}

	return YES;
}


@end


@implementation PCCountedColor

- (id)initWithColor:(NSUIColor*)color count:(NSUInteger)count
{
	self = [super init];

	if ( self )
	{
		self.color = color;
		self.count = count;
	}

	return self;
}

- (NSComparisonResult)compare:(PCCountedColor*)object
{
	if ( [object isKindOfClass:[PCCountedColor class]] )
	{
		if ( self.count < object.count )
		{
			return NSOrderedDescending;
		}
		else if ( self.count == object.count )
		{
			return NSOrderedSame;
		}
	}
    
	return NSOrderedAscending;
}


@end
