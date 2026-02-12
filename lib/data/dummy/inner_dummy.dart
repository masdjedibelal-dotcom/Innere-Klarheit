import '../models/inner_item.dart';

final innerDummy = <InnerItem>[
  InnerItem(
    id: 'in1',
    type: InnerType.staerken,
    title: 'Präzise Klarheit',
    shortDesc: 'Du destillierst Chaos in Entscheidungen.',
    longDesc: 'Du bringst Struktur in diffuse Situationen.',
    questions: [
      'Wann war Klarheit der Wendepunkt?',
      'Was ordnet sich, wenn du präsent bist?',
      'Welche Entscheidung wird leichter?',
    ],
    pitfalls: ['Zu früh schließen', 'Andere nicht mitnehmen'],
    tags: const [],
  ),
  InnerItem(
    id: 'in2',
    type: InnerType.persoenlichkeit,
    title: 'Leise Entschlossenheit',
    shortDesc: 'Du wirkst ruhig, triffst klare Schritte.',
    longDesc: 'Dein Stil ist ruhig, aber stabil.',
    questions: [
      'Wo hilft dir Ruhe, dran zu bleiben?',
      'Welche Schritte sind verlässlich?',
      'Wie kommunizierst du „klar“ ohne Härte?',
    ],
    pitfalls: ['Unterkommunikation', 'Zu viel alleine tragen'],
    tags: const [],
  ),
  InnerItem(
    id: 'in3',
    type: InnerType.werte,
    title: 'Integrität',
    shortDesc: 'Du hältst dein Wort – zuerst dir selbst.',
    longDesc: 'Integrität bringt dir innere Ruhe.',
    questions: [
      'Wo musst du dich neu ausrichten?',
      'Welches Versprechen zählt gerade?',
      'Welche Grenzen schützen dich?',
    ],
    pitfalls: ['Rigide Regeln', 'Selbstkritik'],
    tags: const [],
  ),
  InnerItem(
    id: 'in4',
    type: InnerType.antreiber,
    title: 'Meisterschaft',
    shortDesc: 'Du willst Tiefe statt Lautstärke.',
    longDesc: 'Du suchst Präzision und Wachstum.',
    questions: [
      'Welche Fähigkeit brauchst du als Nächstes?',
      'Wie sieht dein Training aus?',
      'Woran merkst du Fortschritt?',
    ],
    pitfalls: ['Zu hohe Standards', 'Perfektion'],
    tags: const [],
  ),
  InnerItem(
    id: 'in5',
    type: InnerType.staerken,
    title: 'Ruhige Präsenz',
    shortDesc: 'Du stabilisierst Räume ohne Worte.',
    longDesc: 'Deine Präsenz schafft Sicherheit.',
    questions: [
      'Wo spüren andere deine Ruhe?',
      'Wie hältst du Fokus in Chaos?',
      'Was ist dein stabiler Anker?',
    ],
    pitfalls: ['Zu viel in dich ziehen', 'Grenzen vergessen'],
    tags: const [],
  ),
];
