/**
 * @file RadioformDSPEngine.h
 * @brief Objective-C wrapper for Radioform DSP Engine
 *
 * This provides a clean, Swift-friendly API over the C DSP engine.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ============================================================================
// Error Domain
// ============================================================================

extern NSErrorDomain const RadioformDSPErrorDomain;

typedef NS_ERROR_ENUM(RadioformDSPErrorDomain, RadioformDSPError) {
    RadioformDSPErrorNone = 0,
    RadioformDSPErrorNullPointer = 1,
    RadioformDSPErrorInvalidParameter = 2,
    RadioformDSPErrorOutOfMemory = 3,
    RadioformDSPErrorUnknown = 99
};

// ============================================================================
// Filter Types
// ============================================================================

typedef NS_ENUM(NSInteger, RadioformFilterType) {
    RadioformFilterTypePeak = 0,        // Parametric peak/dip
    RadioformFilterTypeLowShelf = 1,    // Low shelf
    RadioformFilterTypeHighShelf = 2,   // High shelf
    RadioformFilterTypeLowPass = 3,     // Low-pass
    RadioformFilterTypeHighPass = 4,    // High-pass
    RadioformFilterTypeNotch = 5,       // Notch filter
    RadioformFilterTypeBandPass = 6     // Band-pass
};

// ============================================================================
// Band Configuration
// ============================================================================

@interface RadioformBand : NSObject <NSCopying>

@property (nonatomic, assign) float frequencyHz;
@property (nonatomic, assign) float gainDb;
@property (nonatomic, assign) float qFactor;
@property (nonatomic, assign) RadioformFilterType filterType;
@property (nonatomic, assign) BOOL enabled;

- (instancetype)initWithFrequency:(float)frequency
                             gain:(float)gain
                          qFactor:(float)q
                       filterType:(RadioformFilterType)type;

@end

// ============================================================================
// Preset Configuration
// ============================================================================

@interface RadioformPreset : NSObject <NSCopying>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSArray<RadioformBand *> *bands;
@property (nonatomic, assign) float preampDb;
@property (nonatomic, assign) BOOL limiterEnabled;
@property (nonatomic, assign) float limiterThresholdDb;

/// Create a flat preset (transparent, no processing)
+ (instancetype)flatPreset;

/// Create a preset with custom bands
+ (instancetype)presetWithName:(NSString *)name bands:(NSArray<RadioformBand *> *)bands;

/// Validate preset parameters
- (BOOL)isValid;

@end

// ============================================================================
// Engine Statistics
// ============================================================================

@interface RadioformStats : NSObject

@property (nonatomic, assign, readonly) uint64_t framesProcessed;
@property (nonatomic, assign, readonly) uint32_t underrunCount;
@property (nonatomic, assign, readonly) float cpuLoadPercent;
@property (nonatomic, assign, readonly) BOOL bypassActive;
@property (nonatomic, assign, readonly) uint32_t sampleRate;

@end

// ============================================================================
// DSP Engine
// ============================================================================

@interface RadioformDSPEngine : NSObject

/// Initialize engine with sample rate
- (nullable instancetype)initWithSampleRate:(uint32_t)sampleRate error:(NSError **)error;

/// Current sample rate
@property (nonatomic, assign, readonly) uint32_t sampleRate;

/// Change sample rate (will reset filter state)
- (BOOL)setSampleRate:(uint32_t)sampleRate error:(NSError **)error;

/// Apply a preset to the engine
- (BOOL)applyPreset:(RadioformPreset *)preset error:(NSError **)error;

/// Get current preset
- (RadioformPreset *)currentPreset;

/// Process interleaved stereo audio (LRLRLR...)
/// @param inputBuffer Input audio samples
/// @param outputBuffer Output audio samples (can be same as input for in-place processing)
/// @param frameCount Number of stereo frames
- (void)processInterleaved:(const float *)inputBuffer
                    output:(float *)outputBuffer
                frameCount:(uint32_t)frameCount;

/// Process planar stereo audio (separate L and R buffers)
/// @param inputLeft Left channel input
/// @param inputRight Right channel input
/// @param outputLeft Left channel output
/// @param outputRight Right channel output
/// @param frameCount Number of frames per channel
- (void)processPlanarLeft:(const float *)inputLeft
                    right:(const float *)inputRight
               outputLeft:(float *)outputLeft
              outputRight:(float *)outputRight
               frameCount:(uint32_t)frameCount;

/// Update a single band's gain in realtime (safe to call from audio thread)
- (void)updateBandGain:(NSUInteger)bandIndex gainDb:(float)gainDb;

/// Update preamp gain in realtime (safe to call from audio thread)
- (void)updatePreampGain:(float)gainDb;

/// Enable/disable bypass (safe to call from audio thread)
@property (nonatomic, assign) BOOL bypass;

/// Reset all filter state (clears delay lines)
- (void)reset;

/// Get current statistics
- (RadioformStats *)statistics;

@end

NS_ASSUME_NONNULL_END
