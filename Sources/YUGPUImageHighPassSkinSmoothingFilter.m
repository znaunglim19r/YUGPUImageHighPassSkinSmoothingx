//
//  YUGPUImageHighPassSkinSmoothing
//
//  Created by YuAo on 1/24/16.
//
//

#import "YUGPUImageHighPassSkinSmoothingFilter.h"
#import "YUGPUImageStillImageHighPassFilter.h"
#import "YUGPUImageDefines.h"
#import <GPUImage/GPUImageThreeInputFilter.h>

NSString * const YUCIHighPassSkinSmoothingMaskBoostFilterFragmentShaderString =
SHADER_STRING
(
 YU_GLSL_FLOAT_PRECISION_LOW
 varying YU_GLSL_PRECISION_HIGH vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 void main() {
     vec3 final = texture2D(inputImageTexture,textureCoordinate).rgb;
     
     float ba = 0.0;
     vec4 hardLightColor = vec4(vec3(final.b), 1.0);
     for (int i =0; i < 3; i++)
     {
         if (hardLightColor.b < 0.5) {
             ba = hardLightColor.b  * hardLightColor.b * 2.;
         } else {
             ba = 1. - (1. - hardLightColor.b) * (1. - hardLightColor.b) * 2.;
         }
         hardLightColor = vec4(vec3(ba), 1.0);
     }
     
     float k = 255.0 / (164.0 - 75.0);
     hardLightColor.r = (hardLightColor.r - 75.0 / 255.0) * k;
     hardLightColor.g = (hardLightColor.g - 75.0 / 255.0) * k;
     hardLightColor.b = (hardLightColor.b - 75.0 / 255.0) * k;
     
     gl_FragColor = hardLightColor;
 }
);

NSString * const YUGPUImageGreenAndBlueChannelOverlayFragmentShaderString =
SHADER_STRING
(
 YU_GLSL_FLOAT_PRECISION_LOW
 varying YU_GLSL_PRECISION_HIGH vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 void main() {
     vec4 image = texture2D(inputImageTexture, textureCoordinate);
     vec4 base = vec4(image.g,image.g,image.g,1.0);
     vec4 overlay = vec4(image.b,image.b,image.b,1.0);
     float ba = 2.0 * overlay.b * base.b + overlay.b * (1.0 - base.a) + base.b * (1.0 - overlay.a);
     gl_FragColor = vec4(ba,ba,ba,1.0);
 }
);

@interface YUCIHighPassSkinSmoothingMaskGenerator : GPUImageFilterGroup

@property (nonatomic) CGFloat highPassRadiusInPixels;

@property (nonatomic,weak) YUGPUImageStillImageHighPassFilter *highPassFilter;

@end

@implementation YUCIHighPassSkinSmoothingMaskGenerator

- (instancetype)init {
    if (self = [super init]) {
        GPUImageFilter *channelOverlayFilter = [[GPUImageFilter alloc] initWithFragmentShaderFromString:YUGPUImageGreenAndBlueChannelOverlayFragmentShaderString];
        [self addFilter:channelOverlayFilter];
        
        YUGPUImageStillImageHighPassFilter *highpassFilter = [[YUGPUImageStillImageHighPassFilter alloc] init];
        [self addFilter:highpassFilter];
        self.highPassFilter = highpassFilter;
        
        GPUImageFilter *maskBoostFilter = [[GPUImageFilter alloc] initWithFragmentShaderFromString:YUCIHighPassSkinSmoothingMaskBoostFilterFragmentShaderString];
        [self addFilter:maskBoostFilter];
        
        [channelOverlayFilter addTarget:highpassFilter];
        [highpassFilter addTarget:maskBoostFilter];
        
        self.initialFilters = @[channelOverlayFilter];
        self.terminalFilter = maskBoostFilter;
    }
    return self;
}

- (void)setHighPassRadiusInPixels:(CGFloat)highPassRadiusInPixels {
    self.highPassFilter.radiusInPixels = highPassRadiusInPixels;
}

- (CGFloat)highPassRadiusInPixels {
    return self.highPassFilter.radiusInPixels;
}

@end

@interface YUGPUImageHighPassSkinSmoothingRadius ()

@property (nonatomic) CGFloat value;
@property (nonatomic) YUGPUImageHighPassSkinSmoothingRadiusUnit unit;

@end

@implementation YUGPUImageHighPassSkinSmoothingRadius

+ (instancetype)radiusInPixels:(CGFloat)pixels {
    YUGPUImageHighPassSkinSmoothingRadius *radius = [YUGPUImageHighPassSkinSmoothingRadius new];
    radius.unit = YUGPUImageHighPassSkinSmoothingRadiusUnitPixel;
    radius.value = pixels;
    return radius;
}

+ (instancetype)radiusAsFractionOfImageWidth:(CGFloat)fraction {
    YUGPUImageHighPassSkinSmoothingRadius *radius = [YUGPUImageHighPassSkinSmoothingRadius new];
    radius.unit = YUGPUImageHighPassSkinSmoothingRadiusUnitFractionOfImageWidth;
    radius.value = fraction;
    return radius;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.value = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(value))] floatValue];
        self.unit = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(unit))] integerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:@(self.value) forKey:NSStringFromSelector(@selector(value))];
    [aCoder encodeObject:@(self.unit) forKey:NSStringFromSelector(@selector(unit))];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end

NSString * const YUGPUImageHighpassSkinSmoothingCompositingFilterFragmentShaderString =
SHADER_STRING
(
 YU_GLSL_FLOAT_PRECISION_LOW
 varying YU_GLSL_PRECISION_HIGH vec2 textureCoordinate;
 varying YU_GLSL_PRECISION_HIGH vec2 textureCoordinate2;
 varying YU_GLSL_PRECISION_HIGH vec2 textureCoordinate3;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 
 void main() {
     vec4 image = texture2D(inputImageTexture, textureCoordinate);
     vec4 toneCurvedImage = texture2D(inputImageTexture2, textureCoordinate);
     vec4 mask = texture2D(inputImageTexture3, textureCoordinate);
     gl_FragColor = vec4(mix(image.rgb,toneCurvedImage.rgb,1.0 - mask.b),1.0);
 }
);

@interface YUGPUImageHighPassSkinSmoothingFilter ()

@property (nonatomic,weak) YUCIHighPassSkinSmoothingMaskGenerator *maskGenerator;

@property (nonatomic,weak) GPUImageDissolveBlendFilter *dissolveFilter;

@property (nonatomic,weak) GPUImageSharpenFilter *sharpenFilter;

@property (nonatomic,weak) GPUImageToneCurveFilter *skinToneCurveFilter;

@property (nonatomic) CGSize currentInputSize;

@end

@implementation YUGPUImageHighPassSkinSmoothingFilter

- (instancetype)init {
    if (self = [super init]) {
        GPUImageExposureFilter *exposureFilter = [[GPUImageExposureFilter alloc] init];
        exposureFilter.exposure = -1.0;
        [self addFilter:exposureFilter];
        
        YUCIHighPassSkinSmoothingMaskGenerator *maskGenerator = [[YUCIHighPassSkinSmoothingMaskGenerator alloc] init];
        [self addFilter:maskGenerator];
        self.maskGenerator = maskGenerator;
        [exposureFilter addTarget:maskGenerator];
        
        GPUImageToneCurveFilter *skinToneCurveFilter = [[GPUImageToneCurveFilter alloc] init];
        [self addFilter:skinToneCurveFilter];
        self.skinToneCurveFilter = skinToneCurveFilter;
        
        GPUImageDissolveBlendFilter *dissolveFilter = [[GPUImageDissolveBlendFilter alloc] init];
        [self addFilter:dissolveFilter];
        self.dissolveFilter = dissolveFilter;
        
        [skinToneCurveFilter addTarget:dissolveFilter atTextureLocation:1];
        
        GPUImageThreeInputFilter *composeFilter = [[GPUImageThreeInputFilter alloc] initWithFragmentShaderFromString:YUGPUImageHighpassSkinSmoothingCompositingFilterFragmentShaderString];
        [self addFilter:composeFilter];
        
        [maskGenerator addTarget:composeFilter atTextureLocation:2];
        [self.dissolveFilter addTarget:composeFilter atTextureLocation:1];
        
        GPUImageSharpenFilter *sharpen = [[GPUImageSharpenFilter alloc] init];
        [self addFilter:sharpen];
        [composeFilter addTarget:sharpen];
        self.sharpenFilter = sharpen;
        
        self.initialFilters = @[exposureFilter,skinToneCurveFilter,dissolveFilter,composeFilter];
        self.terminalFilter = sharpen;
        
        //set defaults
        self.amount = 0.75;
        self.radius = [YUGPUImageHighPassSkinSmoothingRadius radiusAsFractionOfImageWidth:4.5/750.0];
        
        CGPoint controlPoint0 = CGPointMake(0, 0);
        CGPoint controlPoint1 = CGPointMake(120/255.0, 146/255.0);
        CGPoint controlPoint2 = CGPointMake(1.0, 1.0);
        
#if TARGET_OS_IOS
        self.controlPoints = @[[NSValue valueWithCGPoint:controlPoint0],
                               [NSValue valueWithCGPoint:controlPoint1],
                               [NSValue valueWithCGPoint:controlPoint2]];
#else
        self.controlPoints = @[[NSValue valueWithPoint:controlPoint0],
                               [NSValue valueWithPoint:controlPoint1],
                               [NSValue valueWithPoint:controlPoint2]];
#endif
    }
    return self;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex {
    [super setInputSize:newSize atIndex:textureIndex];
    self.currentInputSize = newSize;
    [self updateHighPassRadius];
}

- (void)updateHighPassRadius {
    CGSize inputSize = self.currentInputSize;
    if (inputSize.width * inputSize.height > 0) {
        CGFloat radiusInPixels = 0;
        switch (self.radius.unit) {
            case YUGPUImageHighPassSkinSmoothingRadiusUnitPixel:
                radiusInPixels = self.radius.value;
                break;
            case YUGPUImageHighPassSkinSmoothingRadiusUnitFractionOfImageWidth:
                radiusInPixels = ceil(inputSize.width * self.radius.value);
                break;
            default:
                break;
        }
        if (radiusInPixels != self.maskGenerator.highPassRadiusInPixels) {
            self.maskGenerator.highPassRadiusInPixels = radiusInPixels;
        }
    }
}

- (void)setRadius:(YUGPUImageHighPassSkinSmoothingRadius *)radius {
    _radius = radius.copy;
    [self updateHighPassRadius];
}

- (void)setControlPoints:(NSArray<NSValue *> *)controlPoints {
    self.skinToneCurveFilter.rgbCompositeControlPoints = controlPoints;
}

- (NSArray<NSValue *> *)controlPoints {
    return self.skinToneCurveFilter.rgbCompositeControlPoints;
}

- (void)setAmount:(CGFloat)amount {
    _amount = amount;
    self.sharpenFilter.sharpness = 0.5 * amount;
    self.dissolveFilter.mix = amount;
}

@end
