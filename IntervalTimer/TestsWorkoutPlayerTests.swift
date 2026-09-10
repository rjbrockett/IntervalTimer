// These tests should be moved to a proper test target.
// They are conditionally excluded here to prevent compile errors in the app target.
#if canImport(Testing) && false
import Testing
import Foundation
@testable import IntervalTimer

@Suite("WorkoutPlayer Tests")
struct WorkoutPlayerTests {
    
    @Test("Flattening single block with no repeats")
    func flattenSingleBlockNoRepeats() {
        let intervals = [
            IntervalItem(name: "Warmup", duration: 60, sortOrder: 0),
            IntervalItem(name: "Sprint", duration: 30, sortOrder: 1)
        ]
        let block = IntervalBlock(
            name: "Block 1",
            repeatCount: 1,
            sortOrder: 0,
            intervals: intervals
        )
        let template = WorkoutTemplate(
            name: "Test",
            blocks: [block]
        )
        
        let flattened = WorkoutPlayer.flatten(template: template)
        
        #expect(flattened.count == 2)
        #expect(flattened[0].name == "Warmup")
        #expect(flattened[0].duration == 60)
        #expect(flattened[1].name == "Sprint")
        #expect(flattened[1].duration == 30)
    }
    
    @Test("Flattening single block with repeats")
    func flattenSingleBlockWithRepeats() {
        let intervals = [
            IntervalItem(name: "Work", duration: 20, sortOrder: 0),
            IntervalItem(name: "Rest", duration: 10, sortOrder: 1)
        ]
        let block = IntervalBlock(
            name: "Tabata",
            repeatCount: 3,
            sortOrder: 0,
            intervals: intervals
        )
        let template = WorkoutTemplate(
            name: "Test",
            blocks: [block]
        )
        
        let flattened = WorkoutPlayer.flatten(template: template)
        
        #expect(flattened.count == 6) // 2 intervals × 3 repeats
        #expect(flattened[0].name == "Work")
        #expect(flattened[1].name == "Rest")
        #expect(flattened[2].name == "Work")
        #expect(flattened[3].name == "Rest")
        #expect(flattened[4].name == "Work")
        #expect(flattened[5].name == "Rest")
    }
    
    @Test("Flattening multiple blocks")
    func flattenMultipleBlocks() {
        let warmup = IntervalBlock(
            name: "Warmup",
            repeatCount: 1,
            sortOrder: 0,
            intervals: [
                IntervalItem(name: "Easy", duration: 300, sortOrder: 0)
            ]
        )
        
        let mainSet = IntervalBlock(
            name: "Main",
            repeatCount: 2,
            sortOrder: 1,
            intervals: [
                IntervalItem(name: "Sprint", duration: 60, sortOrder: 0),
                IntervalItem(name: "Recovery", duration: 90, sortOrder: 1)
            ]
        )
        
        let cooldown = IntervalBlock(
            name: "Cooldown",
            repeatCount: 1,
            sortOrder: 2,
            intervals: [
                IntervalItem(name: "Walk", duration: 300, sortOrder: 0)
            ]
        )
        
        let template = WorkoutTemplate(
            name: "Full Workout",
            blocks: [warmup, mainSet, cooldown]
        )
        
        let flattened = WorkoutPlayer.flatten(template: template)
        
        #expect(flattened.count == 6) // 1 + (2×2) + 1
        #expect(flattened[0].name == "Easy")
        #expect(flattened[1].name == "Sprint")
        #expect(flattened[2].name == "Recovery")
        #expect(flattened[3].name == "Sprint")
        #expect(flattened[4].name == "Recovery")
        #expect(flattened[5].name == "Walk")
    }
    
    @Test("Pause and resume changes state")
    func pauseAndResumeState() {
        let template = createSimpleTemplate()
        let player = WorkoutPlayer(template: template)
        
        #expect(player.state == .running)
        
        player.pause()
        #expect(player.state == .paused)
        
        player.resume()
        #expect(player.state == .running)
    }
    
    @Test("Skip to next advances step index")
    func skipToNext() {
        let template = createSimpleTemplate()
        let player = WorkoutPlayer(template: template)
        
        #expect(player.currentStepIndex == 0)
        #expect(player.currentStepName == "Work")
        
        player.skipToNext()
        
        #expect(player.currentStepIndex == 1)
        #expect(player.currentStepName == "Rest")
    }
    
    @Test("Skip to previous goes back one step")
    func skipToPrevious() {
        let template = createSimpleTemplate()
        let player = WorkoutPlayer(template: template)
        
        player.skipToNext() // Move to step 1
        #expect(player.currentStepIndex == 1)
        
        player.skipToPrevious()
        #expect(player.currentStepIndex == 0)
    }
    
    @Test("Current and next step names are correct")
    func stepNamesCorrect() {
        let template = createSimpleTemplate()
        let player = WorkoutPlayer(template: template)
        
        #expect(player.currentStepName == "Work")
        #expect(player.nextStepName == "Rest")
        
        player.skipToNext()
        #expect(player.currentStepName == "Rest")
        #expect(player.nextStepName == "Work")
    }
    
    @Test("Next step name is nil on last step")
    func nextStepNilOnLastStep() {
        let intervals = [
            IntervalItem(name: "Single", duration: 30, sortOrder: 0)
        ]
        let block = IntervalBlock(
            name: "Single Block",
            repeatCount: 1,
            sortOrder: 0,
            intervals: intervals
        )
        let template = WorkoutTemplate(
            name: "Single Step",
            blocks: [block]
        )
        
        let player = WorkoutPlayer(template: template)
        
        #expect(player.currentStepName == "Single")
        #expect(player.nextStepName == nil)
    }
    
    @Test("End changes state to ended")
    func endChangesState() {
        let template = createSimpleTemplate()
        let player = WorkoutPlayer(template: template)
        
        player.end()
        #expect(player.state == .ended)
    }
    
    // MARK: - Helpers
    
    private func createSimpleTemplate() -> WorkoutTemplate {
        let intervals = [
            IntervalItem(name: "Work", duration: 20, sortOrder: 0),
            IntervalItem(name: "Rest", duration: 10, sortOrder: 1)
        ]
        let block = IntervalBlock(
            name: "Tabata",
            repeatCount: 3,
            sortOrder: 0,
            intervals: intervals
        )
        return WorkoutTemplate(
            name: "Test Workout",
            blocks: [block]
        )
    }
}
#endif
