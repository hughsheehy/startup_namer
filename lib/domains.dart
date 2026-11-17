import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A top-level domain the app can check, with the registry that answers for it
/// and its public RDAP service.
class Tld {
  const Tld(this.name, this.registry, this.base);

  /// Without the dot, like "com".
  final String name;

  /// Who runs the RDAP service.
  final String registry;

  /// The RDAP service's address; a domain's record is at `domain/<domain>`.
  final String base;

  String get host => Uri.parse(base).host;

  Uri lookup(String domain) => Uri.parse('${base}domain/$domain');

  @override
  String toString() => '.$name';
}

/// The TLDs the app can check. Each registry's RDAP service is listed by IANA
/// (https://data.iana.org/rdap/dns.json), lets any web page read its answers
/// (CORS), and answers 404 for a name nobody has registered and 200 for one
/// that's taken, as Verisign does for .com. All checked by hand in November 2026.
/// Not here: .io and .co (working services, but not listed by IANA), .nl (SIDN
/// limits lookups hard), .de (DENIC's answers can't be read by web pages), and
/// .ie, .eu and .me (no public RDAP service).
const tlds = <Tld>[
  Tld('com', 'Verisign', 'https://rdap.verisign.com/com/v1/'),
  Tld('net', 'Verisign', 'https://rdap.verisign.com/net/v1/'),
  Tld('org', 'Public Interest Registry', 'https://rdap.publicinterestregistry.org/rdap/'),
  Tld('ai', 'Identity Digital', 'https://rdap.identitydigital.services/rdap/'),
  Tld('app', 'Google Registry', 'https://pubapi.registry.google/rdap/'),
  Tld('dev', 'Google Registry', 'https://pubapi.registry.google/rdap/'),
  Tld('tech', 'Radix', 'https://rdap.radix.host/rdap/'),
  Tld('xyz', 'CentralNic', 'https://rdap.centralnic.com/xyz/'),
  Tld('info', 'Identity Digital', 'https://rdap.identitydigital.services/rdap/'),
  Tld('uk', 'Nominet', 'https://rdap.nominet.uk/uk/'),
];

/// The TLD a domain like "neatchip.com" ends in.
Tld tldOf(String domain) {
  final ending = domain.substring(domain.lastIndexOf('.') + 1);
  return tlds.firstWhere((tld) => tld.name == ending);
}

/// What a registry says about a domain.
enum Availability { checking, free, taken, unknown }

/// What a registry's record says about a taken domain: when it was registered
/// and runs to, through which registrar, its name servers and status. Any of
/// them may be missing.
class DomainRecord {
  const DomainRecord({this.registered, this.expires, this.registrar, this.nameservers = const [], this.status = const []});

  final DateTime? registered;
  final DateTime? expires;
  final String? registrar;

  /// In lower case, like "ns1.atom.com".
  final List<String> nameservers;

  /// RDAP's status values, like "client transfer prohibited" or "pending delete".
  final List<String> status;

  /// Reads an RDAP domain record, or nothing if it isn't one.
  static DomainRecord? parse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      DateTime? event(String action) {
        for (final event in json['events'] as List? ?? const []) {
          if (event is Map && event['eventAction'] == action) return DateTime.tryParse('${event['eventDate']}');
        }
        return null;
      }

      String? registrar;
      for (final entity in json['entities'] as List? ?? const []) {
        if (entity is! Map || !(entity['roles'] as List? ?? const []).contains('registrar')) continue;
        final card = entity['vcardArray'];
        if (card is List && card.length > 1 && card[1] is List) {
          for (final field in card[1] as List) {
            if (field is List && field.length > 3 && field[0] == 'fn' && field[3] is String) registrar = field[3] as String;
          }
        }
      }
      return DomainRecord(
        registered: event('registration'),
        expires: event('expiration'),
        registrar: registrar,
        nameservers: [
          for (final server in json['nameservers'] as List? ?? const [])
            if (server is Map && server['ldhName'] is String)
              (server['ldhName'] as String).toLowerCase().replaceAll(RegExp(r'\.$'), ''),
        ],
        status: [for (final value in json['status'] as List? ?? const []) if (value is String) value],
      );
    } catch (_) {
      return null; // Not JSON, or not shaped like a record: no details, but still taken.
    }
  }

  /// The domain marketplace or parking service its name servers are with, if
  /// it's one of the well-known ones, and whether that's a marketplace (where
  /// it's probably for sale) rather than parking (where the owner may sell).
  ({String name, bool marketplace})? get market {
    for (final server in nameservers) {
      for (final MapEntry(key: host, value: market) in _markets.entries) {
        if (server == host || server.endsWith('.$host')) return market;
      }
    }
    return null;
  }

  /// Whether the registry is deleting it, so it may soon be free.
  bool get beingDeleted => status.any((value) => value.contains('pending delete') || value.contains('redemption'));
}

/// Name servers of domain marketplaces and parking services.
const _markets = <String, ({String name, bool marketplace})>{
  'atom.com': (name: 'Atom', marketplace: true),
  'squadhelp.com': (name: 'Atom', marketplace: true),
  'sedoparking.com': (name: 'Sedo', marketplace: true),
  'afternic.com': (name: 'Afternic', marketplace: true),
  'dan.com': (name: 'Dan.com', marketplace: true),
  'hugedomains.com': (name: 'HugeDomains', marketplace: true),
  'undeveloped.com': (name: 'Undeveloped', marketplace: true),
  'bodis.com': (name: 'Bodis', marketplace: false),
  'parkingcrew.net': (name: 'ParkingCrew', marketplace: false),
  'above.com': (name: 'Above.com', marketplace: false),
};

/// What keeps going wrong with a registry's checks, if anything.
enum Trouble {
  none,

  /// The registry answers, or will, but takes more than a few seconds.
  slow,

  /// No answer at all before the checks give up waiting.
  noReply,

  /// Couldn't connect: offline, blocked, or turned away without a readable answer.
  cantConnect,

  /// The registry said too many requests (429) or too busy (503).
  limited,

  /// The registry answered with some other error, like 500.
  errors;

  /// Whether checks are failing, rather than just slowed.
  bool get serious => this == noReply || this == cantConnect || this == errors;
}

/// Checks domains with every registry the app uses, each through its own
/// [RegistryChecker], so one registry being slow or limiting checks doesn't hold
/// up the others. Registries that serve several TLDs (Verisign for .com and
/// .net) share one, and with it their limits.
class DomainChecker extends ChangeNotifier {
  DomainChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, RegistryChecker> _registries = {};

  RegistryChecker registryFor(Tld tld) =>
      _registries.putIfAbsent(tld.host, () => RegistryChecker(tld.host, client: _client)..addListener(notifyListeners));

  /// The answer so far for `name` (letters only, like "neatchip") under [tld],
  /// asking if it's new: [first], before the others waiting, for one the user
  /// is looking at.
  Availability statusOf(String name, Tld tld, {bool first = false}) =>
      registryFor(tld).statusOf('$name.${tld.name}', first: first);

  /// What the registry's record says about a taken domain, if it said.
  DomainRecord? recordOf(String name, Tld tld) => registryFor(tld).recordOf('$name.${tld.name}');

  /// Asks again, now, about a domain that couldn't be checked.
  void retry(String name, Tld tld) => registryFor(tld).retry('$name.${tld.name}');

  /// Asks again, now, about every domain that couldn't be checked.
  void retryAll() {
    for (final registry in _registries.values) {
      registry.retryAll();
    }
  }

  /// Forgets the domains not yet asked about, and those that couldn't be checked,
  /// as when the list starts again.
  void dropWaiting() {
    for (final registry in _registries.values) {
      registry.dropWaiting();
    }
  }

  /// The registry whose checks keep going wrong, if any: one whose checks are
  /// failing before one that's only slow or limiting.
  RegistryChecker? get troubled {
    final having = _registries.values.where((registry) => registry.trouble != Trouble.none);
    return having.where((registry) => registry.trouble.serious).firstOrNull ?? having.firstOrNull;
  }

  @override
  void dispose() {
    for (final registry in _registries.values) {
      registry.dispose();
    }
    super.dispose();
  }
}

/// Asks one registry's public RDAP service whether domains are registered: it
/// answers 404 for one nobody has. Two at a time, a moment apart, and each
/// domain once.
///
/// Registries publish no limits, but may refuse a browser that asks too often
/// (429 Too Many Requests). Then, or if it can't be reached, the checks slow
/// down, waiting twice as long each time up to a minute (or as long as the
/// registry says), and speed up again once it answers.
///
/// A check that goes wrong, or takes more than [slowAfter], counts as a problem.
/// Once [persistent] checks in a row have, [trouble] says what the latest was,
/// until a check gets a quick answer.
class RegistryChecker extends ChangeNotifier {
  RegistryChecker(this.host, {required http.Client client}) : _client = client;

  /// The RDAP service's host, like "rdap.verisign.com".
  final String host;
  final http.Client _client;
  final Map<String, Availability> _found = {};
  final Map<String, DomainRecord> _records = {};
  final Queue<String> _waiting = Queue();
  final Set<String> _endings = {};
  int _running = 0;
  Timer? _pause;
  Duration _backOff = Duration.zero;
  int _problemsInARow = 0;
  Trouble _lastProblem = Trouble.none;
  int? _lastError;
  static const _atOnce = 2;
  static const _gap = Duration(milliseconds: 250);
  static const _longestBackOff = Duration(minutes: 1);
  static const timeout = Duration(seconds: 10);
  static const slowAfter = Duration(seconds: 3);
  static const persistent = 2;

  /// The TLDs asked about here so far, like [".com", ".net"].
  List<String> get endings => [for (final tld in tlds) if (_endings.contains(tld.name)) '.${tld.name}'];

  /// Whether the registry has pushed back, or not answered, and checks are slower.
  bool get slowedDown => _backOff > Duration.zero;

  /// What keeps going wrong, once [persistent] checks in a row have gone wrong.
  Trouble get trouble => _problemsInARow >= persistent ? _lastProblem : Trouble.none;

  /// How many checks in a row have gone wrong or been slow.
  int get problemsInARow => _problemsInARow;

  /// The HTTP status of the latest error answer, for [Trouble.errors].
  int? get lastError => _lastError;

  /// How long checks wait between tries while slowed down.
  Duration get waitBetweenTries => _gap + _backOff;

  /// How many domains so far couldn't be checked.
  int get unchecked => _found.values.where((status) => status == Availability.unknown).length;

  /// What the registry's record says about a taken `domain`, if it said.
  DomainRecord? recordOf(String domain) => _records[domain];

  /// The answer so far for `domain` (like "neatchip.com"), asking if it's new:
  /// [first], ahead of the others waiting.
  Availability statusOf(String domain, {bool first = false}) {
    final known = _found[domain];
    if (known != null) return known;
    _endings.add(tldOf(domain).name);
    _found[domain] = Availability.checking;
    first ? _waiting.addFirst(domain) : _waiting.add(domain);
    _next();
    return Availability.checking;
  }

  void _next() {
    if (_pause != null) return;
    while (_running < _atOnce && _waiting.isNotEmpty) {
      final domain = _waiting.removeFirst();
      _running++;
      _check(domain).whenComplete(() {
        _running--;
        _pause ??= Timer(_gap + _backOff, () {
          _pause = null;
          _next();
        });
      });
    }
  }

  Future<void> _check(String domain) async {
    // A check still waiting after a few seconds is a problem already, so a
    // registry that doesn't answer shows as slow before the check gives up.
    var counted = false;
    final slow = Timer(slowAfter, () {
      counted = true;
      _problem(Trouble.slow);
    });
    final http.Response response;
    try {
      response = await _client.get(tldOf(domain).lookup(domain)).timeout(timeout);
    } on TimeoutException {
      _slowDown();
      _problem(Trouble.noReply, counted: counted);
      _answer(domain, Availability.unknown);
      return;
    } catch (_) {
      // Offline, or a refusal the page isn't let read (a browser hides an answer
      // that lacks the header saying any page may read it), so slow down too.
      _slowDown();
      _problem(Trouble.cantConnect, counted: counted);
      _answer(domain, Availability.unknown);
      return;
    } finally {
      slow.cancel();
    }
    switch (response.statusCode) {
      case 404 || 200:
        _backOff = Duration.zero;
        if (!counted) _problemsInARow = 0; // A quick answer: all's well again.
        if (response.statusCode == 200) {
          final record = DomainRecord.parse(response.body);
          if (record != null) _records[domain] = record;
        }
        _answer(domain, response.statusCode == 404 ? Availability.free : Availability.taken);
      case 429 || 503:
        // Asked too often, or too busy: ask again, after a pause.
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        _slowDown(seconds == null ? null : Duration(seconds: seconds));
        _waiting.addFirst(domain);
        _problem(Trouble.limited, counted: counted);
      default:
        _lastError = response.statusCode;
        _problem(Trouble.errors, counted: counted);
        _answer(domain, Availability.unknown);
    }
  }

  /// Notes a check that went wrong, once per check: a slow one that then fails
  /// is still one problem, now described by how it failed.
  void _problem(Trouble kind, {bool counted = false}) {
    if (!counted) _problemsInARow++;
    _lastProblem = kind;
    notifyListeners();
  }

  void _slowDown([Duration? asked]) {
    final doubled = _backOff == Duration.zero ? const Duration(seconds: 2) : _backOff * 2;
    _backOff = asked ?? (doubled > _longestBackOff ? _longestBackOff : doubled);
  }

  void _answer(String domain, Availability answer) {
    _found[domain] = answer;
    notifyListeners();
  }

  /// Asks again, now, about a domain that couldn't be checked.
  void retry(String domain) {
    if (_found[domain] != Availability.unknown) return;
    _found[domain] = Availability.checking;
    _waiting.addFirst(domain);
    _pause?.cancel();
    _pause = null;
    _next();
    notifyListeners();
  }

  /// Asks again, now, about every domain that couldn't be checked.
  void retryAll() {
    final domains = [for (final MapEntry(:key, :value) in _found.entries) if (value == Availability.unknown) key];
    if (domains.isEmpty) return;
    for (final domain in domains.reversed) {
      _found[domain] = Availability.checking;
      _waiting.addFirst(domain);
    }
    _pause?.cancel();
    _pause = null;
    _next();
    notifyListeners();
  }

  /// Forgets the domains not yet asked about, and those that couldn't be checked,
  /// as when the list starts again, so domains no longer shown aren't asked
  /// about. Any that show again are asked then.
  void dropWaiting() {
    for (final domain in _waiting) {
      _found.remove(domain);
    }
    _waiting.clear();
    _found.removeWhere((_, status) => status == Availability.unknown);
  }

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }
}
