import Testing
@testable import AgentOfficeKit

struct OfficeMotionTests {

    @Test func easeStartsAndEndsInPlace() {
        #expect(OfficeMotion.easeInOut(0) == 0)
        #expect(OfficeMotion.easeInOut(1) == 1)
        #expect(abs(OfficeMotion.easeInOut(0.5) - 0.5) < 0.0001)
    }

    @Test func easeStaysInRangeAndOnlyMovesForward() {
        #expect(OfficeMotion.easeInOut(-1) == 0)
        #expect(OfficeMotion.easeInOut(2) == 1)
        let steps = (0...20).map { OfficeMotion.easeInOut(Double($0) / 20) }
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $0 <= $1 })
    }
}
