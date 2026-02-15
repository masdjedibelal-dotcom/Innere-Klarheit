class AppCopyItem {
  final String key;
  final String screen;
  final String section;
  final String title;
  final String subtitle;
  final String body;
  final String ctaPrimary;
  final String ctaSecondary;
  final List<String> tags;
  final int sortRank;

  const AppCopyItem({
    required this.key,
    required this.screen,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.ctaPrimary,
    required this.ctaSecondary,
    required this.tags,
    required this.sortRank,
  });

  factory AppCopyItem.empty() {
    return const AppCopyItem(
      key: '',
      screen: '',
      section: '',
      title: '',
      subtitle: '',
      body: '',
      ctaPrimary: '',
      ctaSecondary: '',
      tags: [],
      sortRank: 0,
    );
  }
}

final Map<String, AppCopyItem> appCopy = {
  'home.hero': const AppCopyItem(
    key: 'home.hero',
    screen: 'home',
    section: 'hero',
    title: 'Dein Tag, klar strukturiert.',
    subtitle: 'To-Dos, Termine und Habits in einem System.',
    body:
        'Innen und Leitbild geben Richtung. Der Tagesplan setzt es um.',
    ctaPrimary: 'Weiter',
    ctaSecondary: '',
    tags: ['home', 'theory'],
    sortRank: 1,
  ),
  'home.continuity': const AppCopyItem(
    key: 'home.continuity',
    screen: 'home',
    section: 'micro',
    title: 'Letztes Check-in',
    subtitle: '',
    body: 'Ein Block reicht heute.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['home', 'microcopy'],
    sortRank: 2,
  ),
  'knowledge.feed': const AppCopyItem(
    key: 'knowledge.feed',
    screen: 'knowledge',
    section: 'intro',
    title: 'Wissen, das dich handlungsfähig macht.',
    subtitle: 'Filtere nach Innen, Identität, Load, Output, Off, Progress.',
    body:
        'Kurz, klar, umsetzbar. So wird Wissen zu Handlung.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['knowledge', 'theory'],
    sortRank: 1,
  ),
  'knowledge.reader.end': const AppCopyItem(
    key: 'knowledge.reader.end',
    screen: 'knowledge',
    section: 'cta',
    title: 'Willst du das in dein System übernehmen?',
    subtitle: '',
    body:
        'Übernimm den Snack in deinen Tagesplan.',
    ctaPrimary: 'Speichern',
    ctaSecondary: '',
    tags: ['knowledge', 'cta'],
    sortRank: 2,
  ),
  'inner.intro': const AppCopyItem(
    key: 'inner.intro',
    screen: 'inner',
    section: 'intro',
    title: 'Wähle, was zu dir passt.',
    subtitle: 'Vier Bereiche, ein klarer Start.',
    body:
        'Je 1 Auswahl reicht für den Anfang. Du kannst später verfeinern.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['inner', 'theory'],
    sortRank: 1,
  ),
  'inner.tab.values': const AppCopyItem(
    key: 'inner.tab.values',
    screen: 'inner',
    section: 'tab',
    title: 'Werte',
    subtitle: 'Was dir wichtig ist.',
    body:
        'Wähle 1–3 Werte als Kompass.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['inner', 'values'],
    sortRank: 2,
  ),
  'inner.tab.personality': const AppCopyItem(
    key: 'inner.tab.personality',
    screen: 'inner',
    section: 'tab',
    title: 'Persönlichkeit',
    subtitle: 'Wie du am besten funktionierst.',
    body:
        'Wähle, was dich beschreibt.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['inner', 'personality'],
    sortRank: 3,
  ),
  'inner.tab.drivers': const AppCopyItem(
    key: 'inner.tab.drivers',
    screen: 'inner',
    section: 'tab',
    title: 'Antreiber',
    subtitle: 'Was dich antreibt.',
    body:
        'Erkenne Muster, die dich pushen oder bremsen.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['inner', 'drivers'],
    sortRank: 4,
  ),
  'inner.tab.strengths': const AppCopyItem(
    key: 'inner.tab.strengths',
    screen: 'inner',
    section: 'tab',
    title: 'Stärken',
    subtitle: 'Womit es leicht geht.',
    body:
        'Stärken machen Umsetzung einfacher.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['inner', 'strengths'],
    sortRank: 5,
  ),
  'identity.intro': const AppCopyItem(
    key: 'identity.intro',
    screen: 'identity',
    section: 'intro',
    title: 'Identität formt Verhalten.',
    subtitle:
        'Du wirst nicht zu dem, was du dir vornimmst – sondern zu dem, was du bestätigst.',
    body:
        'Wähle Rollen pro Bereich (Familie, Job, Gesundheit…). Weniger ist besser. Ein Satz kann dein Verhalten den ganzen Tag ausrichten.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['identity', 'theory'],
    sortRank: 1,
  ),
  'identity.roles.hint': const AppCopyItem(
    key: 'identity.roles.hint',
    screen: 'identity',
    section: 'micro',
    title: 'Wähle 1–2 Rollen pro Bereich',
    subtitle: '',
    body: 'Rollen sind Orientierung, nicht Druck. Du darfst täglich zurückkehren.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['identity', 'microcopy'],
    sortRank: 2,
  ),
  'identity.mission': const AppCopyItem(
    key: 'identity.mission',
    screen: 'identity',
    section: 'section',
    title: 'Leitbild',
    subtitle: 'Baue dein Leitbild ohne Tippen.',
    body:
        'Wähle Chips: Ich stehe für … / Ich baue … / Ich schütze … / Ich liefere … → wir rendern daraus dein Leitbild.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['identity', 'mission'],
    sortRank: 3,
  ),
  'system.intro': const AppCopyItem(
    key: 'system.intro',
    screen: 'system',
    section: 'intro',
    title: 'Das System, das dich trägt.',
    subtitle: 'Wenn du scheiterst, fehlt meist Struktur – nicht Motivation.',
    body:
        'Dein System hat vier Bereiche. Wenn Load niedrig ist, repariere zuerst Energie und Off, bevor du Output pushst.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['system', 'theory'],
    sortRank: 1,
  ),
  'system.pillar.load': const AppCopyItem(
    key: 'system.pillar.load',
    screen: 'system',
    section: 'pillar',
    title: 'Load',
    subtitle: 'Energie & Fokus – dein Grundniveau.',
    body:
        'Wenn Load leer ist, fühlt sich alles schwer an. Repariere zuerst den Akku: Schlaf, Ruhe, Umfeld, Klarheit.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['system', 'load'],
    sortRank: 2,
  ),
  'system.pillar.output': const AppCopyItem(
    key: 'system.pillar.output',
    screen: 'system',
    section: 'pillar',
    title: 'Output',
    subtitle: 'Denken → Handeln – ohne Reibung.',
    body:
        'Output ist Startfähigkeit: kleine Schritte, klare Next Actions, geschützte Slots.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['system', 'output'],
    sortRank: 3,
  ),
  'system.pillar.off': const AppCopyItem(
    key: 'system.pillar.off',
    screen: 'system',
    section: 'pillar',
    title: 'Off',
    subtitle: 'Regeneration & Grenzen – Stabilität.',
    body: 'Off schützt dein System. Grenzen sind Teil der Disziplin.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['system', 'off'],
    sortRank: 4,
  ),
  'system.pillar.progress': const AppCopyItem(
    key: 'system.pillar.progress',
    screen: 'system',
    section: 'pillar',
    title: 'Progress',
    subtitle: 'Wiederholung – damit es automatisch wird.',
    body:
        'Progress ist ein Standard, der klein genug ist, um täglich zu passieren. Rückkehr schlägt Neustart.',
    ctaPrimary: '',
    ctaSecondary: '',
    tags: ['system', 'progress'],
    sortRank: 5,
  ),
  'onboarding.hero': const AppCopyItem(
    key: 'onboarding.hero',
    screen: 'onboarding',
    section: 'hero',
    title: 'Schritt 1: Überblick bekommen.',
    subtitle: 'Innen wählen. Tagesplan bauen. Loslegen.',
    body:
        'Du brauchst keinen Druck, nur einen klaren Start. Wir führen dich durch die Basis.',
    ctaPrimary: 'Weiter',
    ctaSecondary: '',
    tags: ['onboarding'],
    sortRank: 1,
  ),
  'onboarding.system': const AppCopyItem(
    key: 'onboarding.system',
    screen: 'onboarding',
    section: 'system',
    title: 'Schritt 2: Innen-Basis wählen.',
    subtitle: 'Wähle je 1 Stärke, 1 Wert, 1 Antreiber, 1 Persönlichkeit.',
    body:
        'Damit dein System zu dir passt, starten wir mit deinem Inneren.',
    ctaPrimary: 'Weiter',
    ctaSecondary: '',
    tags: ['onboarding'],
    sortRank: 2,
  ),
  'onboarding.start': const AppCopyItem(
    key: 'onboarding.start',
    screen: 'onboarding',
    section: 'start',
    title: 'Schritt 3: Starte deinen Tagesplan.',
    subtitle: 'Lege Blöcke an oder füge dein erstes To-Do hinzu.',
    body:
        'Ein klarer Block reicht, um Momentum zu bauen.',
    ctaPrimary: 'Los geht’s',
    ctaSecondary: '',
    tags: ['onboarding'],
    sortRank: 3,
  ),
};

AppCopyItem copy(String key) => appCopy[key] ?? AppCopyItem.empty();


