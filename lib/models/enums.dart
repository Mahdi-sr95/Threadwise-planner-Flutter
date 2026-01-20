enum Difficulty {
  easy,
  medium,
  hard;

  String get displayName {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  static Difficulty fromString(String value) {
    return Difficulty.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => Difficulty.medium,
    );
  }
}

enum Strategy {
  waterfall,
  sandwich,
  sequential,
  randomMix;

  String get displayName {
    switch (this) {
      case Strategy.waterfall:
        return 'Waterfall';
      case Strategy.sandwich:
        return 'Sandwich';
      case Strategy.sequential:
        return 'Sequential';
      case Strategy.randomMix:
        return 'Random Mix';
    }
  }

  String get description {
    switch (this) {
      case Strategy.waterfall:
        return 'Start with hardest topics first, then progress to easier ones';
      case Strategy.sandwich:
        return 'Alternate between hard and easy topics for balanced learning';
      case Strategy.sequential:
        return 'Study topics in order by subject and deadline';
      case Strategy.randomMix:
        return 'Randomized study order for variety and reduced monotony';
    }
  }
}

enum InputStatus {
  unrelated,
  incomplete,
  complete;

  String get message {
    switch (this) {
      case InputStatus.unrelated:
        return 'Your input does not appear to be related to course planning. Please provide course names, deadlines, and difficulty levels.';
      case InputStatus.incomplete:
        return 'Some required information is missing. Please provide course names, deadlines, and difficulty levels for all courses.';
      case InputStatus.complete:
        return 'Input validated successfully.';
    }
  }
}
