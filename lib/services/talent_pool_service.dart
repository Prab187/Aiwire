import '../models/talent_profile.dart';

class TalentPoolService {
  static final List<TalentProfile> _sampleProfiles = [
    TalentProfile(
      id: '1', name: 'Dr. Sarah Chen', title: 'Principal Research Scientist',
      company: 'Google DeepMind', location: 'London, UK',
      specialization: 'Reinforcement Learning',
      skills: ['PyTorch', 'RL', 'Multi-Agent Systems', 'Game Theory'],
      yearsExperience: 12, isAvailable: false, publications: 47, patents: 8, matchScore: 99.2,
    ),
    TalentProfile(
      id: '2', name: 'James Okafor', title: 'Staff ML Engineer',
      company: 'Anthropic', location: 'San Francisco, CA',
      specialization: 'LLM Safety & Alignment',
      skills: ['Python', 'RLHF', 'Constitutional AI', 'Transformers'],
      yearsExperience: 9, isAvailable: true, publications: 23, patents: 3, matchScore: 98.7,
    ),
    TalentProfile(
      id: '3', name: 'Dr. Priya Sharma', title: 'Head of ML',
      company: 'Stripe', location: 'Seattle, WA',
      specialization: 'Fraud Detection & Anomaly ML',
      skills: ['Python', 'XGBoost', 'Deep Learning', 'Real-time Systems'],
      yearsExperience: 11, isAvailable: true, publications: 15, patents: 5, matchScore: 97.9,
    ),
    TalentProfile(
      id: '4', name: 'Alex Kim', title: 'Senior Research Engineer',
      company: 'OpenAI', location: 'San Francisco, CA',
      specialization: 'Generative Models',
      skills: ['Diffusion Models', 'GANs', 'PyTorch', 'Distributed Training'],
      yearsExperience: 7, isAvailable: false, publications: 19, patents: 2, matchScore: 97.5,
    ),
    TalentProfile(
      id: '5', name: 'Dr. Maria Rodriguez', title: 'VP of AI Research',
      company: 'Meta', location: 'Menlo Park, CA',
      specialization: 'Computer Vision',
      skills: ['Vision Transformers', 'Object Detection', 'Video Understanding', 'Self-Supervised Learning'],
      yearsExperience: 15, isAvailable: false, publications: 82, patents: 14, matchScore: 99.5,
    ),
    TalentProfile(
      id: '6', name: 'Yuki Tanaka', title: 'Principal Engineer',
      company: 'NVIDIA', location: 'Tokyo, Japan',
      specialization: 'GPU Computing & ML Infrastructure',
      skills: ['CUDA', 'C++', 'Triton', 'Distributed Systems'],
      yearsExperience: 13, isAvailable: true, publications: 28, patents: 11, matchScore: 98.3,
    ),
    TalentProfile(
      id: '7', name: 'Dr. Amir Hassan', title: 'Lead NLP Scientist',
      company: 'Cohere', location: 'Toronto, Canada',
      specialization: 'Multilingual NLP',
      skills: ['Transformers', 'Tokenization', 'Low-resource Languages', 'Retrieval'],
      yearsExperience: 8, isAvailable: true, publications: 31, patents: 4, matchScore: 97.1,
    ),
    TalentProfile(
      id: '8', name: 'Emma Liu', title: 'Staff Data Scientist',
      company: 'Netflix', location: 'Los Gatos, CA',
      specialization: 'Recommendation Systems',
      skills: ['Collaborative Filtering', 'Deep Retrieval', 'A/B Testing', 'Causal Inference'],
      yearsExperience: 10, isAvailable: false, publications: 12, patents: 6, matchScore: 96.8,
    ),
    TalentProfile(
      id: '9', name: 'Dr. Robert Müller', title: 'Director of AI',
      company: 'Siemens', location: 'Munich, Germany',
      specialization: 'Industrial AI & IoT',
      skills: ['Edge ML', 'Time Series', 'Predictive Maintenance', 'Digital Twins'],
      yearsExperience: 14, isAvailable: true, publications: 35, patents: 19, matchScore: 98.1,
    ),
    TalentProfile(
      id: '10', name: 'Lisa Park', title: 'ML Platform Lead',
      company: 'Uber', location: 'San Francisco, CA',
      specialization: 'ML Platform & MLOps',
      skills: ['Michelangelo', 'Feature Stores', 'Model Serving', 'Kubernetes'],
      yearsExperience: 9, isAvailable: true, publications: 8, patents: 3, matchScore: 96.4,
    ),
  ];

  static Future<List<TalentProfile>> fetchTalentPool({String? specialization, bool? availableOnly}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var profiles = List<TalentProfile>.from(_sampleProfiles);

    if (specialization != null && specialization != 'All') {
      profiles = profiles.where((p) =>
        p.specialization.toLowerCase().contains(specialization.toLowerCase())
      ).toList();
    }
    if (availableOnly == true) {
      profiles = profiles.where((p) => p.isAvailable).toList();
    }

    profiles.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return profiles;
  }

  static int get totalProfiles => _sampleProfiles.length;

  // Analytics data
  static Map<String, dynamic> getPoolStats() {
    final profiles = _sampleProfiles;
    final totalPubs = profiles.fold<int>(0, (sum, p) => sum + p.publications);
    final totalPatents = profiles.fold<int>(0, (sum, p) => sum + p.patents);
    final avgExp = profiles.fold<int>(0, (sum, p) => sum + p.yearsExperience) / profiles.length;
    final available = profiles.where((p) => p.isAvailable).length;

    return {
      'totalProfiles': profiles.length,
      'totalPublications': totalPubs,
      'totalPatents': totalPatents,
      'avgExperience': avgExp,
      'availableNow': available,
      'topPercentile': 0.33,
      'totalITWorkforce': 30000000,
      'elitePoolSize': 99000,
      'specializations': _getSpecializationBreakdown(),
      'locationBreakdown': _getLocationBreakdown(),
      'experienceDistribution': _getExperienceDistribution(),
    };
  }

  static Map<String, int> _getSpecializationBreakdown() {
    final map = <String, int>{};
    for (final p in _sampleProfiles) {
      map[p.specialization] = (map[p.specialization] ?? 0) + 1;
    }
    return map;
  }

  static Map<String, int> _getLocationBreakdown() {
    final map = <String, int>{};
    for (final p in _sampleProfiles) {
      final country = p.location.split(', ').last;
      map[country] = (map[country] ?? 0) + 1;
    }
    return map;
  }

  static Map<String, int> _getExperienceDistribution() {
    int junior = 0, mid = 0, senior = 0, expert = 0;
    for (final p in _sampleProfiles) {
      if (p.yearsExperience < 5) junior++;
      else if (p.yearsExperience < 8) mid++;
      else if (p.yearsExperience < 12) senior++;
      else expert++;
    }
    return {'0-4 yrs': junior, '5-7 yrs': mid, '8-11 yrs': senior, '12+ yrs': expert};
  }
}
