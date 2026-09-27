// Shared doc fixtures for the B1-S6 round-6 invariant probes, ported from
// `scratchpad/stm/vb6/probes/inv_docs.dart` (the round-6 verifier's own
// corpus) plus a few additions the lead's directive called out by name
// (a `**` mid-stream closing rewrite, and a headings doc already covered
// by [flashDocs]).

/// Plain sequential documents: no restructuring event ever occurs (every
/// paragraph/list-item/cell/line is pure tail growth or a pure new tail
/// slot) - content must NEVER pop in these.
const flashDocs = {
  'ul':
      'Intro line here.\n\n- Alpha bravo\n- Charlie delta\n- Echo foxtrot\n'
      '- Golf hotel\n\nDone now. ',
  'ol':
      'Intro line here.\n\n1. Alpha bravo\n2. Charlie delta\n3. Echo foxtrot\n'
      '4. Golf hotel\n\nDone now. ',
  'nested':
      'Intro line here.\n\n- Alpha bravo\n  - Charlie delta\n  - Echo '
      'foxtrot\n- Golf hotel\n\nDone now. ',
  'quote':
      'Intro line here.\n\n> Alpha bravo\n> Charlie delta\n\n> Echo '
      'foxtrot\n\nDone now. ',
  'table':
      'Intro line here.\n\n| Alpha | bravo |\n|---|---|\n| Charlie | delta '
      '|\n| Echo | foxtrot |\n\nDone now. ',
  'headings':
      'Intro line here.\n\n## Alpha bravo\n\nCharlie delta.\n\n### Echo '
      'foxtrot\n\nGolf hotel. ',
  'longList':
      'Items:\n\n- alpha one\n- bravo two\n- charlie three\n- delta four\n'
      '- echo five\n- foxtrot six\n- golf seven\n- hotel eight\n- india '
      'nine\n- juliet ten\n\nFinished. ',
  'code':
      'Intro words.\n\n```\nfirstline here\nsecondline here\n```\n\nAfter '
      'code. ',
};

/// Duplicate/repeated content, always at DISTINCT paint slots (separate
/// list items/cells/paragraphs) - a duplicate is never in-place, so this is
/// still pure tail growth from the mask's point of view and must never pop.
const dupDocs = {
  'ulYes': 'Answers:\n\n- Yes\n- No\n- Yes\n- Maybe\n- Yes\n\nDone. ',
  'ulRepeatLine':
      'Steps:\n\n- Run the tests\n- Fix the code\n- Run the tests\n- Ship '
      'it\n\nEnd. ',
  'table':
      'Grid:\n\n| A | B |\n|---|---|\n| Yes | No |\n| Yes | Yes |\n| No | '
      'No |\n\nEnd. ',
  'paras': 'Hello there.\n\nOk.\n\nHello there.\n\nOk.\n\nFinal words. ',
  'code': 'Code:\n\n```\nfoo();\nbar();\nfoo();\n```\n\nAfter. ',
  'quoteRep': '> Yes\n>\n> Yes\n\nOk Yes. ',
};

/// Genuine mid-stream reflow/restructuring: a paragraph/row/cell's rendered
/// text can transiently change in a way that is NOT growth (a table
/// collapsing to its header while its next row streams in, a nested list
/// re-parenting, a setext/hr line resolving). These MAY legitimately pop
/// (case 4's 2-consecutive-layout adopt-opaque) - `allowPops: true` at the
/// call site, with the pop COUNT still asserted/reported, never silently
/// ignored.
const staleDocs = {
  'tbl2':
      'Intro words.\n\n| Aa | Bb |\n|---|---|\n| one | two |\n| three | '
      'four |\n\nMiddle paragraph words.\n\n| Cc | Dd |\n|---|---|\n| five '
      '| six |\n| seven | eight |\n\nDone now. ',
  'tbl2adj':
      'Intro words.\n\n| Aa | Bb |\n|---|---|\n| one | two |\n| three | '
      'four |\n\n| Cc | Dd | Ee |\n|---|---|---|\n| five | six | nine |\n\n'
      'Done now. ',
  'tblThenList':
      '| Aa | Bb |\n|---|---|\n| one | two |\n| three | four |\n\n- apple '
      'banana cherry\n- grape kiwi lemon\n\nDone now. ',
  'listThenPara':
      'Intro words.\n\n- one two\n- three four\n- five six\n\nAfter list '
      'paragraph with several fresh words.\n\n- seven eight\n\nDone now. ',
  'mixed':
      '# Heading words\n\nLead paragraph text.\n\n- item alpha\n- item '
      'bravo\n\n| Col | Val |\n|---|---|\n| red | green |\n\n```\ncode '
      'line here\nanother code line\n```\n\n> quoted wisdom text\n\n'
      'Closing sentence here. ',
  'olThenUl':
      'Steps below.\n\n1. first step here\n2. second step here\n\n- bullet '
      'alpha\n- bullet bravo\n\nEnd text. ',
  'setext':
      'Title words\n---\n\nBody text here.\n\nAnother title\n===\n\nMore '
      'body words. ',
  'hrs':
      'Before rule.\n\n---\n\nAfter rule words.\n\n***\n\nFinal words '
      'here. ',
};

/// Content that recurs identically at a LATER, distinct tail slot after an
/// earlier occurrence - never a same-slot rewrite, so this must also never
/// pop (this is precisely the class of bug rounds 1-5's cleverness caused
/// via cross-slot matching; the round-6 design does none, so recurrence
/// alone can no longer cause a pop).
const orphanDocs = {
  'prefixLater':
      'Steps:\n\n- Install\n- Build\n- Test\n\nThen later on:\n\n- Install '
      'the app\n- Build it now\n\nEnd. ',
  'repeatLater':
      'First list:\n\n- Apples\n- Pears\n- Plums\n\nSecond list follows '
      'here:\n\n- Apples\n- Pears\n\nEnd. ',
  'olRepeat':
      'Plan:\n\n1. Check logs\n2. Restart server\n\nRetry:\n\n1. Check '
      'logs\n2. Restart server again\n\nEnd. ',
  'tableThenList':
      '| Key | Value |\n|---|---|\n| Speed | Fast |\n\nNotes:\n\n- Speed\n'
      '- Fast enough\n\nEnd. ',
};
