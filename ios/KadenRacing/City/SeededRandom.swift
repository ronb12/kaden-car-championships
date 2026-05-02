import Foundation

/// Deterministic RNG for procedural cities — same seed → same track + module picks.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        // SplitMix64-style mixing so weak seeds still spread.
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        z ^= z >> 30
        z &*= 0xBF58_476D_1CE4_E5B9
        z ^= z >> 27
        z &*= 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        state = z == 0 ? 0xDEAD_BEEF_C0FF_EE01 : z
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0xA076_1D64_78BD_F5FB
        var z = state
        z ^= z >> 32
        z &*= 0xD6EA_50FA_FEC9_AA05
        z ^= z >> 32
        z &*= 0xD6EA_50FA_FEC9_AA05
        z ^= z >> 32
        return z
    }

    mutating func unitFloat() -> Float {
        Float(nextUInt64() & 0xFFFF_FFFF) / Float(0xFFFF_FFFF)
    }

    mutating func float(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + unitFloat() * (range.upperBound - range.lowerBound)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(nextUInt64() % max(span, 1))
    }

    /// Stable seed for circuit / time trial (theme + player picks).
    static func layoutSeed(theme: CityThemeID, trackIndex: Int, lapCount: Int) -> UInt64 {
        let a = UInt64(theme.rawValue &* 10_007)
        let b = UInt64(trackIndex &* 98_017)
        let c = UInt64(lapCount &* 1_000_003)
        return a ^ (b &<< 21) ^ (c &<< 43) ^ 0xC1C0_1E1D_0000
    }
}
