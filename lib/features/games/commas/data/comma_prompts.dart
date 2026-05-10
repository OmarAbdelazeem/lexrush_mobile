import 'package:lexrush/features/games/commas/domain/entities/comma_difficulty.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_insertion_point.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_prompt.dart';
import 'package:lexrush/features/games/commas/domain/entities/comma_rule_type.dart';

const List<CommaPrompt> commaPrompts = <CommaPrompt>[
  CommaPrompt(
    id: 'location_beginner_001',
    displayTextWithoutCommas: 'The Taj Mahal is located in Agra India.',
    correctTextWithCommas: 'The Taj Mahal is located in Agra, India.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 6,
        beforeToken: 'Agra',
        afterToken: 'India.',
      ),
    ],
    ruleType: CommaRuleType.location,
    difficulty: CommaDifficulty.beginner,
    beginnerSafe: true,
    explanation: 'Use a comma between a city and a country or state.',
  ),
  CommaPrompt(
    id: 'date_beginner_001',
    displayTextWithoutCommas: 'We leave Thursday August 30.',
    correctTextWithCommas: 'We leave Thursday, August 30.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 2,
        beforeToken: 'Thursday',
        afterToken: 'August',
      ),
    ],
    ruleType: CommaRuleType.date,
    difficulty: CommaDifficulty.beginner,
    beginnerSafe: true,
    explanation: 'Use a comma between the day of the week and the date.',
  ),
  CommaPrompt(
    id: 'intro_beginner_001',
    displayTextWithoutCommas: 'After dinner we walked home.',
    correctTextWithCommas: 'After dinner, we walked home.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 1,
        beforeToken: 'dinner',
        afterToken: 'we',
      ),
    ],
    ruleType: CommaRuleType.introductoryPhrase,
    difficulty: CommaDifficulty.beginner,
    beginnerSafe: true,
    explanation: 'Use a comma after a short introductory phrase.',
  ),
  CommaPrompt(
    id: 'direct_address_beginner_001',
    displayTextWithoutCommas: 'Maria please close the door.',
    correctTextWithCommas: 'Maria, please close the door.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 0,
        beforeToken: 'Maria',
        afterToken: 'please',
      ),
    ],
    ruleType: CommaRuleType.directAddress,
    difficulty: CommaDifficulty.beginner,
    beginnerSafe: true,
    explanation: 'Use a comma after a name when speaking directly to someone.',
  ),
  CommaPrompt(
    id: 'contrast_beginner_001',
    displayTextWithoutCommas: 'However we stayed inside.',
    correctTextWithCommas: 'However, we stayed inside.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 0,
        beforeToken: 'However',
        afterToken: 'we',
      ),
    ],
    ruleType: CommaRuleType.contrast,
    difficulty: CommaDifficulty.beginner,
    beginnerSafe: true,
    explanation: 'Use a comma after an opening contrast word like however.',
  ),
  CommaPrompt(
    id: 'compound_beginner_001',
    displayTextWithoutCommas: 'I wanted tea but Lena made coffee.',
    correctTextWithCommas: 'I wanted tea, but Lena made coffee.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 2,
        beforeToken: 'tea',
        afterToken: 'but',
      ),
    ],
    ruleType: CommaRuleType.compoundSentence,
    difficulty: CommaDifficulty.beginner,
    beginnerSafe: true,
    explanation:
        'Use a comma before a coordinating conjunction joining two clauses.',
  ),
  CommaPrompt(
    id: 'date_medium_001',
    displayTextWithoutCommas: 'We leave Thursday August 30 after lunch.',
    correctTextWithCommas: 'We leave Thursday, August 30, after lunch.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 2,
        beforeToken: 'Thursday',
        afterToken: 'August',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 4,
        beforeToken: '30',
        afterToken: 'after',
      ),
    ],
    ruleType: CommaRuleType.date,
    difficulty: CommaDifficulty.medium,
    beginnerSafe: false,
    explanation:
        'Set off a full date from the rest of the sentence with commas.',
  ),
  CommaPrompt(
    id: 'list_medium_001',
    displayTextWithoutCommas: 'The frog can be yellow green red or blue.',
    correctTextWithCommas: 'The frog can be yellow, green, red, or blue.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 4,
        beforeToken: 'yellow',
        afterToken: 'green',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 5,
        beforeToken: 'green',
        afterToken: 'red',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 6,
        beforeToken: 'red',
        afterToken: 'or',
      ),
    ],
    ruleType: CommaRuleType.list,
    difficulty: CommaDifficulty.medium,
    beginnerSafe: false,
    explanation:
        'Use commas to separate items in a list, including before the final or.',
  ),
  CommaPrompt(
    id: 'list_medium_002',
    displayTextWithoutCommas: 'I packed socks shirts and shoes.',
    correctTextWithCommas: 'I packed socks, shirts, and shoes.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 2,
        beforeToken: 'socks',
        afterToken: 'shirts',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 3,
        beforeToken: 'shirts',
        afterToken: 'and',
      ),
    ],
    ruleType: CommaRuleType.list,
    difficulty: CommaDifficulty.medium,
    beginnerSafe: false,
    explanation: 'Use commas between three or more list items.',
  ),
  CommaPrompt(
    id: 'location_medium_001',
    displayTextWithoutCommas: 'In Paris France we visited museums.',
    correctTextWithCommas: 'In Paris, France, we visited museums.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 1,
        beforeToken: 'Paris',
        afterToken: 'France',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 2,
        beforeToken: 'France',
        afterToken: 'we',
      ),
    ],
    ruleType: CommaRuleType.location,
    difficulty: CommaDifficulty.medium,
    beginnerSafe: false,
    explanation:
        'Use commas around a city-country or city-state pair inside a sentence.',
  ),
  CommaPrompt(
    id: 'intro_medium_001',
    displayTextWithoutCommas: 'Before the bell rang everyone found a seat.',
    correctTextWithCommas: 'Before the bell rang, everyone found a seat.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 3,
        beforeToken: 'rang',
        afterToken: 'everyone',
      ),
    ],
    ruleType: CommaRuleType.introductoryPhrase,
    difficulty: CommaDifficulty.medium,
    beginnerSafe: false,
    explanation: 'Use a comma after an introductory clause.',
  ),
  CommaPrompt(
    id: 'appositive_medium_001',
    displayTextWithoutCommas: 'My brother a careful driver avoids highways.',
    correctTextWithCommas: 'My brother, a careful driver, avoids highways.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 1,
        beforeToken: 'brother',
        afterToken: 'a',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 4,
        beforeToken: 'driver',
        afterToken: 'avoids',
      ),
    ],
    ruleType: CommaRuleType.appositive,
    difficulty: CommaDifficulty.medium,
    beginnerSafe: false,
    explanation: 'Use commas around a phrase that renames or explains a noun.',
  ),
  CommaPrompt(
    id: 'list_medium_003',
    displayTextWithoutCommas: 'We bought apples oranges bananas and grapes.',
    correctTextWithCommas: 'We bought apples, oranges, bananas, and grapes.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 2,
        beforeToken: 'apples',
        afterToken: 'oranges',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 3,
        beforeToken: 'oranges',
        afterToken: 'bananas',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 4,
        beforeToken: 'bananas',
        afterToken: 'and',
      ),
    ],
    ruleType: CommaRuleType.list,
    difficulty: CommaDifficulty.medium,
    beginnerSafe: false,
    explanation: 'Use commas to separate every item in a longer list.',
  ),
  CommaPrompt(
    id: 'mixed_hard_001',
    displayTextWithoutCommas:
        'After the storm ended the children who had waited all morning ran outside to play.',
    correctTextWithCommas:
        'After the storm ended, the children, who had waited all morning, ran outside to play.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 3,
        beforeToken: 'ended',
        afterToken: 'the',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 5,
        beforeToken: 'children',
        afterToken: 'who',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 10,
        beforeToken: 'morning',
        afterToken: 'ran',
      ),
    ],
    ruleType: CommaRuleType.nonrestrictiveClause,
    difficulty: CommaDifficulty.hard,
    beginnerSafe: false,
    explanation:
        'Use commas after an introductory clause and around nonessential information.',
  ),
  CommaPrompt(
    id: 'mixed_hard_002',
    displayTextWithoutCommas:
        'On Monday May 6 we met Nora our project lead in Austin Texas.',
    correctTextWithCommas:
        'On Monday, May 6, we met Nora, our project lead, in Austin, Texas.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 1,
        beforeToken: 'Monday',
        afterToken: 'May',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 3,
        beforeToken: '6',
        afterToken: 'we',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 6,
        beforeToken: 'Nora',
        afterToken: 'our',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 9,
        beforeToken: 'lead',
        afterToken: 'in',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 11,
        beforeToken: 'Austin',
        afterToken: 'Texas.',
      ),
    ],
    ruleType: CommaRuleType.appositive,
    difficulty: CommaDifficulty.hard,
    beginnerSafe: false,
    explanation:
        'Dates, appositives, and city-state names all need comma support.',
  ),
  CommaPrompt(
    id: 'mixed_hard_003',
    displayTextWithoutCommas:
        'The old library which closed last winter will reopen in June and the mayor will attend.',
    correctTextWithCommas:
        'The old library, which closed last winter, will reopen in June, and the mayor will attend.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 2,
        beforeToken: 'library',
        afterToken: 'which',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 6,
        beforeToken: 'winter',
        afterToken: 'will',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 11,
        beforeToken: 'June',
        afterToken: 'and',
      ),
    ],
    ruleType: CommaRuleType.nonrestrictiveClause,
    difficulty: CommaDifficulty.hard,
    beginnerSafe: false,
    explanation:
        'Set off nonessential clauses and use a comma before a conjunction joining clauses.',
  ),
  CommaPrompt(
    id: 'mixed_hard_004',
    displayTextWithoutCommas:
        'Yes Jordan I saved the notes but I forgot the charts graphs and photos.',
    correctTextWithCommas:
        'Yes, Jordan, I saved the notes, but I forgot the charts, graphs, and photos.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 0,
        beforeToken: 'Yes',
        afterToken: 'Jordan',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 1,
        beforeToken: 'Jordan',
        afterToken: 'I',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 5,
        beforeToken: 'notes',
        afterToken: 'but',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 11,
        beforeToken: 'charts',
        afterToken: 'graphs',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 12,
        beforeToken: 'graphs',
        afterToken: 'and',
      ),
    ],
    ruleType: CommaRuleType.directAddress,
    difficulty: CommaDifficulty.hard,
    beginnerSafe: false,
    explanation:
        'Direct address, compound clauses, and lists each require commas here.',
  ),
  CommaPrompt(
    id: 'mixed_hard_005',
    displayTextWithoutCommas:
        'Although Maya was tired she reviewed the essay corrected the citations and submitted it before midnight.',
    correctTextWithCommas:
        'Although Maya was tired, she reviewed the essay, corrected the citations, and submitted it before midnight.',
    insertionPoints: <CommaInsertionPoint>[
      CommaInsertionPoint(
        afterTokenIndex: 3,
        beforeToken: 'tired',
        afterToken: 'she',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 7,
        beforeToken: 'essay',
        afterToken: 'corrected',
      ),
      CommaInsertionPoint(
        afterTokenIndex: 10,
        beforeToken: 'citations',
        afterToken: 'and',
      ),
    ],
    ruleType: CommaRuleType.introductoryPhrase,
    difficulty: CommaDifficulty.hard,
    beginnerSafe: false,
    explanation:
        'Use a comma after the opening clause and between items in a series of actions.',
  ),
];
