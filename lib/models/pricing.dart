class Pricing {
  final int adultDay;
  final int adultCamping;
  final int childDay;
  final int childCamping;

  const Pricing({
    required this.adultDay,
    required this.adultCamping,
    required this.childDay,
    required this.childCamping,
  });

  factory Pricing.fromMap(Map<String, dynamic> m) => Pricing(
        adultDay: (m['adult_day'] ?? 7000) as int,
        adultCamping: (m['adult_camping'] ?? 8000) as int,
        childDay: (m['child_day'] ?? 5000) as int,
        childCamping: (m['child_camping'] ?? 6000) as int,
      );

  Map<String, dynamic> toMap() => {
        'adult_day': adultDay,
        'adult_camping': adultCamping,
        'child_day': childDay,
        'child_camping': childCamping,
      };
}
