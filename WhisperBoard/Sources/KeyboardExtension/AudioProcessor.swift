import Accelerate
import Foundation

/// Audio processor for preprocessing audio samples before WhisperKit transcription
/// Uses Accelerate framework for efficient DSP operations
final class AudioProcessor {
    
    // MARK: - Types
    
    struct ProcessingConfig {
        let targetSampleRate: Double
        let normalization: Bool
        let preEmphasis: Float
        let dcOffsetRemoval: Bool
        
        static let `default` = ProcessingConfig(
            targetSampleRate: 16000,
            normalization: true,
            preEmphasis: 0.97,
            dcOffsetRemoval: true
        )
    }
    
    // MARK: - Properties
    
    private let config: ProcessingConfig
    private var preEmphasisFilter: [Float]
    
    // MARK: - Initialization
    
    init(config: ProcessingConfig = .default) {
        self.config = config
        self.preEmphasisFilter = [1, -config.preEmphasis]
        
        print("[AudioProcessor] Initialized with config: sampleRate=\(Int(config.targetSampleRate))Hz, normalization=\(config.normalization)")
    }
    
    // MARK: - Public Methods
    
    /// Process audio samples from Data
    /// - Parameter audioData: Raw audio data as Data
    /// - Returns: Processed samples as Float array
    func process(_ audioData: Data) -> [Float]? {
        let samples = dataToFloat(audioData)
        guard !samples.isEmpty else { return nil }
        
        return process(samples)
    }
    
    /// Process audio samples from Float array
    /// - Parameter samples: Input audio samples
    /// - Returns: Processed audio samples
    func process(_ samples: [Float]) -> [Float] {
        var processed = samples
        
        // Remove DC offset
        if config.dcOffsetRemoval {
            processed = removeDCOffset(processed)
        }
        
        // Apply pre-emphasis filter
        processed = applyPreEmphasis(processed)
        
        // Normalize audio
        if config.normalization {
            processed = normalize(processed)
        }
        
        return processed
    }
    
    /// Convert Data to Float array
    private func dataToFloat(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        var samples = [Float](repeating: 0, count: count)
        data.copyBytes(to: UnsafeMutableBufferPointer(start: &samples, count: count))
        return samples
    }
    
    /// Convert Float array to Data
    func floatToData(_ samples: [Float]) -> Data {
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }
    
    /// Compute RMS energy of audio
    func computeEnergy(_ samples: [Float]) -> Float {
        var energy: Float = 0
        vDSP_svesq(samples, 1, &energy, vDSP_Length(samples.count))
        return energy / Float(samples.count)
    }
    
    /// Compute RMS energy as dB
    func computeEnergyDB(_ samples: [Float]) -> Float {
        let energy = computeEnergy(samples)
        guard energy > 0 else { return -Float.infinity }
        return 10 * log10f(energy)
    }
    
    /// Detect silence in audio samples
    func isSilence(_ samples: [Float], threshold: Float = 0.01) -> Bool {
        return computeEnergy(samples) < threshold * threshold
    }
    
    /// Calculate signal statistics
    func calculateStats(_ samples: [Float]) -> SignalStats {
        var mean: Float = 0
        var stdDev: Float = 0
        var minVal: Float = 0
        var maxVal: Float = 0
        
        vDSP_normalize(samples, 1, nil, 1, &minVal, &maxVal, vDSP_Length(samples.count))
        vDSP_meanv(samples, 1, &mean, vDSP_Length(samples.count))
        
        var variance: Float = 0
        for sample in samples {
            let diff = sample - mean
            variance += diff * diff
        }
        variance /= Float(samples.count)
        stdDev = sqrtf(variance)
        
        var maxValOut: Float = 0
        vDSP_maxmgv(samples, 1, &maxValOut, vDSP_Length(samples.count))
        var minValOut: Float = 0
        vDSP_minmgv(samples, 1, &minValOut, vDSP_Length(samples.count))
        
        return SignalStats(
            mean: mean,
            stdDev: stdDev,
            min: minValOut,
            max: maxValOut,
            sampleCount: samples.count
        )
    }
    
    // MARK: - Private Methods
    
    /// Remove DC offset from signal
    private func removeDCOffset(_ samples: [Float]) -> [Float] {
        var mean: Float = 0
        vDSP_meanv(samples, 1, &mean, vDSP_Length(samples.count))
        
        // Subtract mean from each sample manually
        return samples.map { $0 - mean }
    }
    
    /// Apply pre-emphasis filter to enhance high frequencies
    private func applyPreEmphasis(_ samples: [Float]) -> [Float] {
        guard samples.count > 1 else { return samples }
        
        var result = [Float](repeating: 0, count: samples.count)
        result[0] = samples[0]
        
        for i in 1..<samples.count {
            result[i] = samples[i] - preEmphasisFilter[1] * samples[i - 1]
        }
        
        return result
    }
    
    /// Normalize audio to [-1, 1] range
    private func normalize(_ samples: [Float]) -> [Float] {
        var maxAbs: Float = 0
        vDSP_maxmgv(samples, 1, &maxAbs, vDSP_Length(samples.count))
        
        guard maxAbs > 0 else { return samples }
        
        var factor: Float = 1.0 / maxAbs
        var result = [Float](repeating: 0, count: samples.count)
        vDSP_vsmul(samples, 1, &factor, &result, 1, vDSP_Length(samples.count))
        
        return result
    }
}

/// Signal statistics structure
struct SignalStats {
    let mean: Float
    let stdDev: Float
    let min: Float
    let max: Float
    let sampleCount: Int
}

// End of AudioProcessor