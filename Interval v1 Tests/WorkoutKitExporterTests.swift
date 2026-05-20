import Testing
import WorkoutKit
@testable import Interval_v1

@Suite("WorkoutKitExporter conversion")
@MainActor
struct WorkoutKitExporterTests {

    private let exporter = WorkoutKitExporter.shared

    @Test("Standard Tabata: 8 rounds, rest > 0 — splits into [N-1, 1] blocks")
    func tabataSplitsIntoTwoBlocks() {
        let workout = Workout(name: "Tabata", workSeconds: 30, restSeconds: 15, rounds: 8)
        let custom = exporter.makeCustomWorkout(from: workout)

        // Two blocks: 7 × [work, rest] + 1 × [work]
        #expect(custom.blocks.count == 2)
        #expect(custom.blocks[0].iterations == 7)
        #expect(custom.blocks[0].steps.count == 2)
        #expect(custom.blocks[1].iterations == 1)
        #expect(custom.blocks[1].steps.count == 1)
        #expect(custom.displayName == "Tabata")
    }

    @Test("Rest=0: collapses to single block with N work-only iterations")
    func zeroRestSingleBlock() {
        let workout = Workout(name: "Continuous", workSeconds: 60, restSeconds: 0, rounds: 5)
        let custom = exporter.makeCustomWorkout(from: workout)

        #expect(custom.blocks.count == 1)
        #expect(custom.blocks[0].iterations == 5)
        #expect(custom.blocks[0].steps.count == 1)
    }

    @Test("Single round with rest>0: still single block, no recovery step")
    func singleRoundWithRest() {
        let workout = Workout(name: "Single", workSeconds: 45, restSeconds: 30, rounds: 1)
        let custom = exporter.makeCustomWorkout(from: workout)

        #expect(custom.blocks.count == 1)
        #expect(custom.blocks[0].iterations == 1)
        #expect(custom.blocks[0].steps.count == 1)
    }

    @Test("Single round, rest=0: minimal single block")
    func singleRoundNoRest() {
        let workout = Workout(name: "Sprint", workSeconds: 20, restSeconds: 0, rounds: 1)
        let custom = exporter.makeCustomWorkout(from: workout)

        #expect(custom.blocks.count == 1)
        #expect(custom.blocks[0].iterations == 1)
    }

    @Test("Activity type is HIIT and location is indoor")
    func activityMetadata() {
        let workout = Workout(name: "X", workSeconds: 30, restSeconds: 15, rounds: 4)
        let custom = exporter.makeCustomWorkout(from: workout)

        #expect(custom.activity == .highIntensityIntervalTraining)
        #expect(custom.location == .indoor)
    }
}
