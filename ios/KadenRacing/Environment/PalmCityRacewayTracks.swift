import Foundation
import simd

/// Six authored Palm City Raceway circuits (reference layout sheet).
enum PalmCityRacewayTracks {

    enum Layout: Int, CaseIterable {
        case harborRun = 0
        case downtownLoop
        case coastalDash
        case bayviewSprint
        case industrialCircuit
        case fullThrottle

        var displayName: String {
            switch self {
            case .harborRun: return "Harbor Run"
            case .downtownLoop: return "Downtown Loop"
            case .coastalDash: return "Coastal Dash"
            case .bayviewSprint: return "Bayview Sprint"
            case .industrialCircuit: return "Industrial Circuit"
            case .fullThrottle: return "Full Throttle"
            }
        }

        var lengthTag: String {
            switch self {
            case .harborRun: return "2.45 MI"
            case .downtownLoop: return "3.10 MI"
            case .coastalDash: return "4.20 MI"
            case .bayviewSprint: return "2.15 MI"
            case .industrialCircuit: return "3.85 MI"
            case .fullThrottle: return "5.62 MI"
            }
        }

        var defaultLaps: Int {
            // Short races by default — track select stepper lets players go higher (up to 30).
            switch self {
            case .bayviewSprint: return 4
            case .harborRun: return 4
            case .downtownLoop, .industrialCircuit: return 4
            case .coastalDash: return 4
            case .fullThrottle: return 5
            }
        }

        var prefersOcean: Bool {
            switch self {
            case .harborRun, .coastalDash, .bayviewSprint, .fullThrottle: return true
            default: return false
            }
        }
    }

    private static let scale: Float = 2.5

    static func makeTrack(index: Int) -> ClosedTrackSpline {
        let layout = Layout(rawValue: ((index % Layout.allCases.count) + Layout.allCases.count) % Layout.allCases.count) ?? .harborRun
        switch layout {
        case .harborRun: return harborRun()
        case .downtownLoop: return downtownLoop()
        case .coastalDash: return coastalDash()
        case .bayviewSprint: return bayviewSprint()
        case .industrialCircuit: return industrialCircuit()
        case .fullThrottle: return fullThrottle()
        }
    }

    static func layout(for index: Int) -> Layout {
        Layout(rawValue: ((index % Layout.allCases.count) + Layout.allCases.count) % Layout.allCases.count) ?? .harborRun
    }

    // MARK: - Circuits

    /// Tight harbor / port loop — 90° corners along the waterfront.
    private static func harborRun() -> ClosedTrackSpline {
        closedLoop(segments: 96) { t in
            let s = sin(t)
            let c = cos(t)
            // Rounded rectangle with pinched harbor leg.
            let x = 62 * s + 24 * sin(2 * t) + 10 * cos(4 * t)
            let z = 48 * c + 18 * cos(3 * t)
            return SIMD3<Float>(x, 0, z)
        }
    }

    /// Dense downtown street circuit — technical esses and grid corners.
    private static func downtownLoop() -> ClosedTrackSpline {
        closedLoop(segments: 104) { t in
            let s = sin(t)
            let c = cos(t)
            let x = 72 * s + 22 * sin(4 * t) + 12 * cos(5 * t)
            let z = 64 * c + 20 * cos(4 * t) - 14 * sin(6 * t)
            return SIMD3<Float>(x, 0, z)
        }
    }

    /// Long coastal sweep — flowing bends following the shoreline.
    private static func coastalDash() -> ClosedTrackSpline {
        closedLoop(segments: 112) { t in
            let s = sin(t)
            let c = cos(t)
            let x = 98 * s + 16 * sin(2 * t) + 8 * cos(3 * t)
            let z = 74 * c * (1 + 0.36 * sin(2 * t)) + 12 * sin(4 * t)
            return SIMD3<Float>(x, 0, z)
        }
    }

    /// Short bay loop — wide gentle curves, high-speed sprint.
    private static func bayviewSprint() -> ClosedTrackSpline {
        closedLoop(segments: 72) { t in
            let s = sin(t)
            let c = cos(t)
            let x = 54 * s + 8 * sin(3 * t)
            let z = 50 * c + 6 * cos(2 * t)
            return SIMD3<Float>(x, 0, z)
        }
    }

    /// Industrial zone — long straights linked by hairpins and wide bends.
    private static func industrialCircuit() -> ClosedTrackSpline {
        closedLoop(segments: 100) { t in
            let s = sin(t)
            let c = cos(t)
            let x = 92 * c + 34 * cos(2 * t) + 14 * sin(3 * t)
            let z = 38 * s + 28 * sin(2 * t)
            return SIMD3<Float>(x, 0, z)
        }
    }

    /// Full Palm City tour — longest mixed loop with varied sectors.
    private static func fullThrottle() -> ClosedTrackSpline {
        closedLoop(segments: 128) { t in
            let s = sin(t)
            let c = cos(t)
            let x = 112 * s + 26 * sin(2 * t) + 10 * cos(5 * t)
            let z = 82 * c + 22 * cos(3 * t) + 14 * sin(4 * t)
            let y = 6.5 * sin(t - 0.5) + 2.4 * sin(2.2 * t)
            return SIMD3<Float>(x, y, z)
        }
    }

    // MARK: - Helpers

    private static func closedLoop(
        segments: Int,
        sample: (Float) -> SIMD3<Float>
    ) -> ClosedTrackSpline {
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(segments)
        for i in 0..<segments {
            let t = Float(i) / Float(segments) * 2 * Float.pi
            let p = sample(t)
            points.append(SIMD3<Float>(p.x * scale, p.y * scale, p.z * scale))
        }
        return ClosedTrackSpline(points: points)
    }
}
