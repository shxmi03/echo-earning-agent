import Foundation

/// Mirrors `lessons.kind` in schema.sql.
public enum LessonKind: String, Codable, Sendable {
    case concept, exerciseSet = "exercise_set", song, starGate = "star_gate"
}

public struct ExerciseNote: Codable, Sendable, Hashable {
    public let pitch: Pitch
    public let hand: Hand
    public let finger: Int

    public init(pitch: Pitch, hand: Hand = .right, finger: Int) {
        self.pitch = pitch
        self.hand = hand
        self.finger = finger
    }
}

/// A static exercise (S11): read each note and play it, no clock.
public struct Exercise: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let prompt: String
    public let clef: Clef
    public let notes: [ExerciseNote]

    public init(id: String, prompt: String, clef: Clef, notes: [ExerciseNote]) {
        self.id = id
        self.prompt = prompt
        self.clef = clef
        self.notes = notes
    }
}

/// The short theory card before the exercises (S10). Fix 6: teach the why.
public struct ConceptCard: Codable, Sendable, Hashable {
    public let title: String
    public let paragraphs: [String]
    /// Keys to light up on the keyboard picture.
    public let keys: [Pitch]
    /// An optional tip about posture or fingering.
    public let tip: String?

    public init(title: String, paragraphs: [String], keys: [Pitch], tip: String?) {
        self.title = title
        self.paragraphs = paragraphs
        self.keys = keys
        self.tip = tip
    }
}

public struct Lesson: Codable, Sendable, Identifiable, Hashable {
    public let id: String          // a UUID, same as lessons.id
    public let title: String
    public let summary: String
    public let kind: LessonKind
    public let minutes: Int
    public let concept: ConceptCard?
    public let exercises: [Exercise]

    public init(id: String, title: String, summary: String, kind: LessonKind, minutes: Int,
                concept: ConceptCard?, exercises: [Exercise]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.kind = kind
        self.minutes = minutes
        self.concept = concept
        self.exercises = exercises
    }
}

public struct Course: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let summary: String
    public let isFree: Bool
    public let contentVersion: Int
    public let lessons: [Lesson]

    public init(id: String, title: String, summary: String, isFree: Bool, contentVersion: Int, lessons: [Lesson]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.isFree = isFree
        self.contentVersion = contentVersion
        self.lessons = lessons
    }

    public func lesson(after id: String) -> Lesson? {
        guard let i = lessons.firstIndex(where: { $0.id == id }), i + 1 < lessons.count else { return nil }
        return lessons[i + 1]
    }
}

public enum SeedContent {
    public enum LoadError: Error { case missing(String) }

    /// The free first course, bundled with the app so lesson 1 works offline on day one.
    public static func firstCourse() throws -> Course {
        guard let url = Bundle.module.url(forResource: "first-steps", withExtension: "json") else {
            throw LoadError.missing("first-steps.json")
        }
        return try JSONDecoder().decode(Course.self, from: Data(contentsOf: url))
    }
}
