import 'package:flutter/material.dart';

/// Each universe has multiple physically different tables sharing an art style.
enum PinballUniverseId { celestial, neon, clockwork }

enum PinballTableId {
  astralOrrery, moonfallSanctuary, nebulaTempest,
  circuitVelocity, quantumGrid, reactorRush,
  grandMechanism, chronoCitadel, brassLabyrinth,
}

class PinballUniverseInfo {
  const PinballUniverseInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.accent,
  });

  final PinballUniverseId id;
  final String title;
  final String description;
  final Color accent;

  String get coverAsset => 'assets/universe_covers/${id.name}.png';
}

const pinballUniverses = <PinballUniverseInfo>[
  PinballUniverseInfo(
    id: PinballUniverseId.celestial, title: 'CELESTIAL REALMS',
    description: 'Ancient stars, portals, and impossible cosmic machines',
    accent: Color(0xFF7AE5FF),
  ),
  PinballUniverseInfo(
    id: PinballUniverseId.neon, title: 'NEON METROPOLIS',
    description: 'Electric velocity, reactive circuits, and living technology',
    accent: Color(0xFF3DF3FF),
  ),
  PinballUniverseInfo(
    id: PinballUniverseId.clockwork, title: 'CLOCKWORK EMPIRE',
    description: 'Hidden machinery, brass kingdoms, and time itself',
    accent: Color(0xFFFFCE7B),
  ),
];

class PinballTableInfo {
  const PinballTableInfo({
    required this.id, required this.universe, required this.variant,
    required this.title, required this.subtitle, required this.tagline,
    required this.base, required this.accent, required this.secondary,
    required this.modeNames,
  });

  final PinballTableId id;
  final PinballUniverseId universe;
  final int variant; // 0, 1 or 2: distinct layout and obstacle behavior.
  final String title;
  final String subtitle;
  final String tagline;
  final Color base;
  final Color accent;
  final Color secondary;
  final List<String> modeNames;

  String get storageKey => 'pinball_best_${id.name}';
  String get coverAsset => 'assets/universe_covers/${universe.name}.png';
}

const pinballTables = <PinballTableInfo>[
  PinballTableInfo(
    id: PinballTableId.astralOrrery,
    universe: PinballUniverseId.celestial, variant: 0,
    title: 'THE ASTRAL ORRERY', subtitle: 'Classic celestial precision',
    tagline: 'Awaken the stars. Command the cosmos.',
    base: Color(0xFF091229), accent: Color(0xFF7AE5FF),
    secondary: Color(0xFFC28CFF),
    modeNames: <String>['Ignition', 'Star Alignment', 'Eclipse', 'Astral Ascension'],
  ),
  PinballTableInfo(
    id: PinballTableId.moonfallSanctuary,
    universe: PinballUniverseId.celestial, variant: 1,
    title: 'MOONFALL SANCTUARY', subtitle: 'Lunar gravity labyrinth',
    tagline: 'Bend lunar tides to unlock hidden paths.',
    base: Color(0xFF11172E), accent: Color(0xFFB7E8FF),
    secondary: Color(0xFFABA6FF),
    modeNames: <String>['First Crescent', 'Tidal Pull', 'Full Moon', 'Moonfall'],
  ),
  PinballTableInfo(
    id: PinballTableId.nebulaTempest,
    universe: PinballUniverseId.celestial, variant: 2,
    title: 'NEBULA TEMPEST', subtitle: 'Storm of the constellations',
    tagline: 'Ride shifting storm lanes through the nebula.',
    base: Color(0xFF17102A), accent: Color(0xFF86D9FF),
    secondary: Color(0xFFD77CFF),
    modeNames: <String>['Gather Clouds', 'Storm Gates', 'Supercell', 'Nebula Nova'],
  ),
  PinballTableInfo(
    id: PinballTableId.circuitVelocity,
    universe: PinballUniverseId.neon, variant: 0,
    title: 'CIRCUIT VELOCITY', subtitle: 'Hyper-speed precision shots',
    tagline: 'Light up the circuit. Chase the overdrive.',
    base: Color(0xFF080B20), accent: Color(0xFF3DF3FF),
    secondary: Color(0xFFFF4BD5),
    modeNames: <String>['Charge', 'Circuit Break', 'Turbo Loop', 'Overdrive'],
  ),
  PinballTableInfo(
    id: PinballTableId.quantumGrid,
    universe: PinballUniverseId.neon, variant: 1,
    title: 'QUANTUM GRID', subtitle: 'Teleport and relay puzzles',
    tagline: 'Jump lanes and chain impossible relay shots.',
    base: Color(0xFF0A1229), accent: Color(0xFF6FE0FF),
    secondary: Color(0xFFFF5BC1),
    modeNames: <String>['Handshake', 'Phase Shift', 'Grid Cascade', 'Quantum Break'],
  ),
  PinballTableInfo(
    id: PinballTableId.reactorRush,
    universe: PinballUniverseId.neon, variant: 2,
    title: 'REACTOR RUSH', subtitle: 'Core control and overload',
    tagline: 'Charge the reactor before the energy surges.',
    base: Color(0xFF0B1023), accent: Color(0xFF52F5E6),
    secondary: Color(0xFFFF6388),
    modeNames: <String>['Warm Start', 'Heat Sink', 'Critical Mass', 'Overload'],
  ),
  PinballTableInfo(
    id: PinballTableId.grandMechanism,
    universe: PinballUniverseId.clockwork, variant: 0,
    title: 'THE GRAND MECHANISM', subtitle: 'Mechanical gear choreography',
    tagline: 'Wind the gears. Unlock the legend.',
    base: Color(0xFF23120E), accent: Color(0xFFFFCE7B),
    secondary: Color(0xFFCC7948),
    modeNames: <String>['Wind Up', 'Gear Alignment', 'Chrono Lock', 'Grand Mechanism'],
  ),
  PinballTableInfo(
    id: PinballTableId.chronoCitadel,
    universe: PinballUniverseId.clockwork, variant: 1,
    title: 'CHRONO CITADEL', subtitle: 'Timed gates and changing routes',
    tagline: 'Beat the clock and open the fortress.',
    base: Color(0xFF241710), accent: Color(0xFFFFD996),
    secondary: Color(0xFFCF9050),
    modeNames: <String>['Clock In', 'Timed Entry', 'Frozen Hour', 'Master Clock'],
  ),
  PinballTableInfo(
    id: PinballTableId.brassLabyrinth,
    universe: PinballUniverseId.clockwork, variant: 2,
    title: 'BRASS LABYRINTH', subtitle: 'Living maze and shifting walls',
    tagline: 'Find the moving pathway to the brass vault.',
    base: Color(0xFF26150F), accent: Color(0xFFFFC875),
    secondary: Color(0xFFD87950),
    modeNames: <String>['Secret Passage', 'Turning Maze', 'Vault Key', 'Brass Crown'],
  ),
];

PinballTableInfo tableById(PinballTableId id) =>
    pinballTables.firstWhere((table) => table.id == id);

List<PinballTableInfo> tablesInUniverse(PinballUniverseId id) =>
    pinballTables.where((table) => table.universe == id).toList(growable: false);
