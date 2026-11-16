import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:startup_namer/domains.dart';

/// An RDAP record shaped like Verisign's for boldbond.com.
String record({List<String> nameservers = const ['NS1.ATOM.COM', 'NS2.ATOM.COM'], List<String> status = const []}) =>
    jsonEncode({
      'objectClassName': 'domain',
      'ldhName': 'BOLDBOND.COM',
      'status': status.isEmpty ? ['client transfer prohibited'] : status,
      'events': [
        {'eventAction': 'registration', 'eventDate': '2019-07-10T12:00:00Z'},
        {'eventAction': 'expiration', 'eventDate': '2027-07-10T12:00:00Z'},
        {'eventAction': 'last changed', 'eventDate': '2026-07-11T12:00:00Z'},
      ],
      'entities': [
        {
          'roles': ['registrar'],
          'vcardArray': [
            'vcard',
            [
              ['version', {}, 'text', '4.0'],
              ['fn', {}, 'text', 'GoDaddy.com, LLC'],
            ],
          ],
        },
      ],
      'nameservers': [for (final server in nameservers) {'ldhName': server}],
    });

void main() {
  test('a record gives the dates, registrar and name servers', () {
    final parsed = DomainRecord.parse(record())!;
    expect(parsed.registered, DateTime.utc(2019, 7, 10, 12));
    expect(parsed.expires, DateTime.utc(2027, 7, 10, 12));
    expect(parsed.registrar, 'GoDaddy.com, LLC');
    expect(parsed.nameservers, ['ns1.atom.com', 'ns2.atom.com']);
    expect(parsed.status, ['client transfer prohibited']);
  });

  test('name servers at a marketplace or parking service say so', () {
    expect(DomainRecord.parse(record())!.market, (name: 'Atom', marketplace: true));
    expect(DomainRecord.parse(record(nameservers: ['ns1.sedoparking.com']))!.market, (name: 'Sedo', marketplace: true));
    expect(DomainRecord.parse(record(nameservers: ['ns1.bodis.com']))!.market, (name: 'Bodis', marketplace: false));
    expect(DomainRecord.parse(record(nameservers: ['ns1.example.com']))!.market, isNull);
    // Not fooled by a host that only ends the same way.
    expect(DomainRecord.parse(record(nameservers: ['ns1.notatom.com']))!.market, isNull);
  });

  test("Nominet's trailing dots go, and deletion shows", () {
    expect(DomainRecord.parse(record(nameservers: ['DDNS0.BBC.CO.UK.']))!.nameservers, ['ddns0.bbc.co.uk']);
    expect(DomainRecord.parse(record(status: ['pending delete']))!.beingDeleted, isTrue);
    expect(DomainRecord.parse(record(status: ['redemption period']))!.beingDeleted, isTrue);
    expect(DomainRecord.parse(record())!.beingDeleted, isFalse);
  });

  test('anything that is not a record gives none', () {
    expect(DomainRecord.parse(''), isNull);
    expect(DomainRecord.parse('<html>busy</html>'), isNull);
    expect(DomainRecord.parse('[1, 2]'), isNull);
    expect(DomainRecord.parse('{"events": "nonsense"}'), isNull);
    expect(DomainRecord.parse('{}'), isNotNull); // A record that says nothing: still taken.
  });
}
