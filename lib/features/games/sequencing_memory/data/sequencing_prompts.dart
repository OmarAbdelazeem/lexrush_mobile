import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_difficulty.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_prompt.dart';

const List<SequencingPrompt> sequencingPrompts = <SequencingPrompt>[
  SequencingPrompt(
    id: 'abbeyhill_route',
    theme: SequencingTheme.route,
    difficulty: SequencingDifficulty.beginner,
    beginnerSafe: true,
    items: <String>[
      'Right on Abbeyhill',
      'Exit onto Horse Wynd',
      'Left on Calton Road',
      'Continue onto Canongate',
      'Turn right on North Bridge',
      'Arrive at Princes Street',
    ],
  ),
  SequencingPrompt(
    id: 'museum_route',
    theme: SequencingTheme.route,
    difficulty: SequencingDifficulty.beginner,
    beginnerSafe: true,
    items: <String>[
      'Pass the city museum',
      'Turn left on King Street',
      'Cross the stone bridge',
      'Veer right at Market Road',
      'Walk past the clock tower',
      'Stop at the library',
    ],
  ),
  SequencingPrompt(
    id: 'garden_route',
    theme: SequencingTheme.route,
    difficulty: SequencingDifficulty.beginner,
    beginnerSafe: true,
    items: <String>[
      'Start beside the fountain',
      'Follow the garden path',
      'Turn right after the gate',
      'Pass the glasshouse',
      'Cross the small courtyard',
      'Finish near the station',
    ],
  ),
  SequencingPrompt(
    id: 'campus_errand',
    theme: SequencingTheme.campus,
    difficulty: SequencingDifficulty.medium,
    items: <String>[
      'Collect the lab notes',
      'Visit the east lecture hall',
      'Drop forms at reception',
      'Take stairs to level three',
      'Meet beside the archive room',
      'Return through the main quad',
    ],
  ),
];
