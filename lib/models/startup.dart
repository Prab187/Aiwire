class AIStartup {
  final String id;
  final String name;
  final String description;
  final String category; // LLM, Computer Vision, Robotics, MLOps, Healthcare AI, etc.
  final String founded; // e.g. 'Jan 2021'
  final String location;
  final String stage; // Seed, Series A, Series B, Series C+, Public
  final String? funding;
  final String? lastFundingDate; // e.g. 'Mar 2024'
  final int? teamSize;
  final String? website;
  final List<String> tags;
  final bool isNew;

  AIStartup({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.founded,
    required this.location,
    required this.stage,
    this.funding,
    this.lastFundingDate,
    this.teamSize,
    this.website,
    required this.tags,
    this.isNew = false,
  });
}

class JobForecast {
  final String role;
  final int currentOpenings;
  final double growthPercent; // YoY growth
  final String demandLevel; // High, Very High, Extreme
  final String avgSalary;
  final String trend; // up, stable, down

  JobForecast({
    required this.role,
    required this.currentOpenings,
    required this.growthPercent,
    required this.demandLevel,
    required this.avgSalary,
    required this.trend,
  });
}
