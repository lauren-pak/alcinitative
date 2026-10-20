/// Support services shown by the help button on every post.
///
/// Verified 20 October 2026 (therapyroute.com Singapore crisis line list,
/// checked August 2026). Re-check against each organisation's own website
/// before launch, and periodically after: a wrong number here could hurt
/// someone in crisis. Still needed: a verified Singapore eating-disorder
/// service (see docs/feed-design.md).
class SupportService {
  const SupportService(this.name, this.detail, this.contact);

  final String name;
  final String detail;
  final String contact;
}

const supportServices = [
  SupportService(
    'Emergency',
    'If you or someone else is in danger right now.',
    'Call 995',
  ),
  SupportService(
    'Samaritans of Singapore (SOS)',
    'Talk to someone if you are struggling or having thoughts of '
        'suicide. 24 hours.',
    'Call 1767 · WhatsApp 9151 1767',
  ),
  SupportService(
    'National Mindline',
    'Mental health support by phone, WhatsApp or web chat. 24 hours.',
    'Call 1771 · WhatsApp 6669 1771 · mindline.sg',
  ),
];
