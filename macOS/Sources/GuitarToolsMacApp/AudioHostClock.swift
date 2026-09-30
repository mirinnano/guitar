import AVFoundation
import Darwin
import Foundation

protocol AudioHostClock:
    Sendable {

    func nowSeconds() -> Double

    func seconds(
        forHostTime hostTime: UInt64
    ) -> Double

    func hostTime(
        forSeconds seconds: Double
    ) -> UInt64
}

struct SystemAudioHostClock:
    AudioHostClock {

    func nowSeconds() -> Double {
        AVAudioTime.seconds(
            forHostTime:
                mach_absolute_time()
        )
    }

    func seconds(
        forHostTime hostTime: UInt64
    ) -> Double {
        AVAudioTime.seconds(
            forHostTime:
                hostTime
        )
    }

    func hostTime(
        forSeconds seconds: Double
    ) -> UInt64 {
        AVAudioTime.hostTime(
            forSeconds:
                seconds
        )
    }
}
