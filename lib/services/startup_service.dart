import '../models/startup.dart';

class StartupService {
  static final List<AIStartup> _startups = [
    AIStartup(id: '1', name: 'Anthropic', description: 'AI safety company building reliable, interpretable AI systems. Creator of Claude.',
      category: 'LLM', founded: 'Jan 2021', location: 'San Francisco, CA', stage: 'Series D',
      funding: '\$7.3B', lastFundingDate: 'Jan 2025', teamSize: 900, tags: ['AI Safety', 'LLM', 'Claude'], website: 'anthropic.com'),
    AIStartup(id: '2', name: 'Mistral AI', description: 'European AI lab building open-weight foundation models for enterprise deployment.',
      category: 'LLM', founded: 'Apr 2023', location: 'Paris, France', stage: 'Series B',
      funding: '\$640M', lastFundingDate: 'Jun 2024', teamSize: 60, tags: ['Open Source', 'LLM', 'Enterprise'], website: 'mistral.ai', isNew: true),
    AIStartup(id: '3', name: 'Cohere', description: 'Enterprise NLP platform providing language AI for search, generation, and classification.',
      category: 'LLM', founded: 'Nov 2019', location: 'Toronto, Canada', stage: 'Series D',
      funding: '\$970M', lastFundingDate: 'Jul 2024', teamSize: 450, tags: ['NLP', 'Enterprise', 'RAG'], website: 'cohere.com'),
    AIStartup(id: '4', name: 'Runway', description: 'Generative AI for creative tools — video, image, and multimodal content generation.',
      category: 'Generative AI', founded: 'Mar 2018', location: 'New York, NY', stage: 'Series D',
      funding: '\$240M', lastFundingDate: 'Jun 2024', teamSize: 150, tags: ['Video AI', 'Creative', 'Generative'], website: 'runwayml.com'),
    AIStartup(id: '5', name: 'Hugging Face', description: 'The open-source AI community platform. Hosts models, datasets, and ML tools.',
      category: 'MLOps', founded: 'May 2016', location: 'New York, NY', stage: 'Series D',
      funding: '\$395M', lastFundingDate: 'Aug 2023', teamSize: 250, tags: ['Open Source', 'Models', 'Community'], website: 'huggingface.co'),
    AIStartup(id: '6', name: 'Sakana AI', description: 'Nature-inspired AI research lab building evolutionary and swarm-based foundation models.',
      category: 'Research', founded: 'Jul 2023', location: 'Tokyo, Japan', stage: 'Series A',
      funding: '\$300M', lastFundingDate: 'Sep 2024', teamSize: 45, tags: ['Research', 'Evolution', 'Foundation Models'], website: 'sakana.ai', isNew: true),
    AIStartup(id: '7', name: 'Figure AI', description: 'Building general-purpose humanoid robots powered by AI for commercial use.',
      category: 'Robotics', founded: 'Mar 2022', location: 'Sunnyvale, CA', stage: 'Series B',
      funding: '\$754M', lastFundingDate: 'Feb 2024', teamSize: 300, tags: ['Robotics', 'Humanoid', 'Manufacturing'], website: 'figure.ai', isNew: true),
    AIStartup(id: '8', name: 'Glean', description: 'AI-powered enterprise search and knowledge management across all company apps.',
      category: 'Enterprise AI', founded: 'Aug 2019', location: 'Palo Alto, CA', stage: 'Series D',
      funding: '\$360M', lastFundingDate: 'Feb 2024', teamSize: 500, tags: ['Enterprise', 'Search', 'RAG'], website: 'glean.com'),
    AIStartup(id: '9', name: 'Poolside', description: 'AI code generation company building next-gen coding assistants for developers.',
      category: 'Code AI', founded: 'May 2023', location: 'San Francisco, CA', stage: 'Series A',
      funding: '\$500M', lastFundingDate: 'Oct 2024', teamSize: 80, tags: ['Code', 'Developer Tools', 'LLM'], website: 'poolside.ai', isNew: true),
    AIStartup(id: '10', name: 'Recursion', description: 'AI-driven drug discovery platform using machine learning to decode biology.',
      category: 'Healthcare AI', founded: 'Oct 2013', location: 'Salt Lake City, UT', stage: 'Public',
      funding: '\$1.5B', lastFundingDate: 'Apr 2021', teamSize: 600, tags: ['Drug Discovery', 'Biotech', 'ML'], website: 'recursion.com'),
    AIStartup(id: '11', name: 'Pika', description: 'AI video generation startup making cinematic video creation accessible to everyone.',
      category: 'Generative AI', founded: 'Apr 2023', location: 'Palo Alto, CA', stage: 'Series B',
      funding: '\$135M', lastFundingDate: 'Nov 2024', teamSize: 40, tags: ['Video', 'Generative', 'Creative'], website: 'pika.art', isNew: true),
    AIStartup(id: '12', name: 'Weights & Biases', description: 'ML experiment tracking, model management, and data versioning platform.',
      category: 'MLOps', founded: 'Feb 2017', location: 'San Francisco, CA', stage: 'Series C',
      funding: '\$250M', lastFundingDate: 'Oct 2023', teamSize: 300, tags: ['MLOps', 'Experiment Tracking', 'Platform'], website: 'wandb.ai'),
    AIStartup(id: '13', name: 'Adept AI', description: 'Building AI agents that can take actions in software on behalf of users.',
      category: 'AI Agents', founded: 'Jan 2022', location: 'San Francisco, CA', stage: 'Series B',
      funding: '\$415M', lastFundingDate: 'Mar 2024', teamSize: 100, tags: ['Agents', 'Automation', 'Multimodal'], website: 'adept.ai'),
    AIStartup(id: '14', name: 'Cerebras Systems', description: 'Building the world\'s largest AI chips and fastest AI inference infrastructure.',
      category: 'AI Hardware', founded: 'Dec 2015', location: 'Sunnyvale, CA', stage: 'Series F',
      funding: '\$720M', lastFundingDate: 'Nov 2021', teamSize: 400, tags: ['Chips', 'Hardware', 'Inference'], website: 'cerebras.net'),
    AIStartup(id: '15', name: 'ElevenLabs', description: 'AI voice synthesis and cloning platform for realistic speech generation.',
      category: 'Audio AI', founded: 'Jan 2022', location: 'New York, NY', stage: 'Series B',
      funding: '\$101M', lastFundingDate: 'Jan 2024', teamSize: 50, tags: ['Voice', 'TTS', 'Audio'], website: 'elevenlabs.io', isNew: true),
  ];

  static final List<JobForecast> _forecasts = [
    JobForecast(role: 'ML Engineer', currentOpenings: 48500, growthPercent: 34, demandLevel: 'Very High', avgSalary: '\$175K', trend: 'up'),
    JobForecast(role: 'AI Research Scientist', currentOpenings: 12800, growthPercent: 28, demandLevel: 'High', avgSalary: '\$210K', trend: 'up'),
    JobForecast(role: 'Prompt Engineer', currentOpenings: 22000, growthPercent: 156, demandLevel: 'Extreme', avgSalary: '\$130K', trend: 'up'),
    JobForecast(role: 'Data Scientist', currentOpenings: 85000, growthPercent: 12, demandLevel: 'High', avgSalary: '\$145K', trend: 'stable'),
    JobForecast(role: 'MLOps Engineer', currentOpenings: 18500, growthPercent: 52, demandLevel: 'Very High', avgSalary: '\$165K', trend: 'up'),
    JobForecast(role: 'AI Product Manager', currentOpenings: 9200, growthPercent: 45, demandLevel: 'Very High', avgSalary: '\$185K', trend: 'up'),
    JobForecast(role: 'Computer Vision Eng.', currentOpenings: 15000, growthPercent: 22, demandLevel: 'High', avgSalary: '\$170K', trend: 'up'),
    JobForecast(role: 'NLP Engineer', currentOpenings: 19500, growthPercent: 38, demandLevel: 'Very High', avgSalary: '\$168K', trend: 'up'),
    JobForecast(role: 'AI Ethics Specialist', currentOpenings: 3200, growthPercent: 85, demandLevel: 'High', avgSalary: '\$140K', trend: 'up'),
    JobForecast(role: 'Robotics ML Eng.', currentOpenings: 8700, growthPercent: 30, demandLevel: 'High', avgSalary: '\$175K', trend: 'up'),
  ];

  static Future<List<AIStartup>> fetchStartups({String? category}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var list = List<AIStartup>.from(_startups);
    if (category != null && category != 'All') {
      list = list.where((s) => s.category == category).toList();
    }
    list.sort((a, b) {
      if (a.isNew && !b.isNew) return -1;
      if (!a.isNew && b.isNew) return 1;
      return 0;
    });
    return list;
  }

  static Future<List<JobForecast>> fetchForecasts() async {
    await Future.delayed(const Duration(milliseconds: 200));
    var list = List<JobForecast>.from(_forecasts);
    list.sort((a, b) => b.growthPercent.compareTo(a.growthPercent));
    return list;
  }

  static int get totalStartups => _startups.length;
  static int get newThisMonth => _startups.where((s) => s.isNew).length;
  static List<String> get categories => _startups.map((s) => s.category).toSet().toList()..sort();
}
