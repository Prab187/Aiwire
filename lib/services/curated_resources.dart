/// Curated whitelist of AI/ML learning resources with verified 2026 URLs.
/// When Claude suggests a resource, it MUST pick from this list — prevents
/// hallucinated or dead URLs that would destroy user trust.
///
/// Format: skill keyword → best resources for each level.
class CuratedResources {
  /// Returns a comma-separated list of valid resources for a given skill keyword.
  /// Claude is instructed to ONLY pick from this list.
  static String forSkill(String skill) {
    final key = skill.toLowerCase();
    final matching = <String>[];
    for (final entry in _catalog.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        matching.addAll(entry.value);
      }
    }
    if (matching.isEmpty) {
      // Fall back to general AI/ML resources
      matching.addAll(_catalog['machine learning'] ?? []);
    }
    return matching.take(5).join(' | ');
  }

  /// Returns the full catalog as a prompt-friendly block (for prompts
  /// that need Claude to know the full menu).
  static String get fullCatalog {
    final buf = StringBuffer();
    for (final entry in _catalog.entries) {
      buf.writeln('${entry.key.toUpperCase()}:');
      for (final r in entry.value) {
        buf.writeln('  - $r');
      }
    }
    return buf.toString();
  }

  /// Compact provider list for prompts that are already near token limits.
  /// ~200 tokens vs ~1500 for fullCatalog. Claude still gets enough to avoid
  /// inventing course names, but without eating all the budget.
  static String get compactProviders => '''
Prefer these real 2026 providers (use exact names): Coursera (DeepLearning.AI, Andrew Ng ML Specialization, IBM Data Science), Udemy (Stephane Maarek for AWS/GCP/Azure certs, Jose Portilla, Angela Yu), Fast.ai (Practical Deep Learning), Hugging Face NLP Course, DeepLearning.AI short courses (LLMs, Prompt Engineering, MLOps), freeCodeCamp, Kaggle Learn, Stanford CS229/CS224N/CS231N on YouTube, Anthropic/OpenAI official docs, PyTorch tutorials, Google Cloud Skills Boost, AWS Skill Builder, Microsoft Learn.
URLs must use real domain roots: coursera.org, udemy.com, fast.ai, huggingface.co, deeplearning.ai, pytorch.org, tensorflow.org, cloudskillsboost.google, skillbuilder.aws, learn.microsoft.com, kaggle.com/learn. If unsure of exact URL, set resource_url to null — do NOT invent.''';

  /// skill keyword → list of "Provider: Course Name | URL | Level | Cost"
  static const Map<String, List<String>> _catalog = {
    'python': [
      'Coursera: Python for Everybody (Univ of Michigan) | https://www.coursera.org/specializations/python | Beginner | Free audit / \$49/mo',
      'Udemy: 100 Days of Python (Angela Yu) | https://www.udemy.com/course/100-days-of-code | Beginner | ₹499-\$15',
      'freeCodeCamp: Python for Everybody | https://www.freecodecamp.org/learn | Beginner | Free',
    ],
    'machine learning': [
      'Coursera: Machine Learning Specialization (Andrew Ng) | https://www.coursera.org/specializations/machine-learning-introduction | Beginner | Free audit / \$49/mo',
      'Coursera: Deep Learning Specialization (Andrew Ng) | https://www.coursera.org/specializations/deep-learning | Intermediate | Free audit',
      'Fast.ai: Practical Deep Learning | https://course.fast.ai | Intermediate | Free',
      'Stanford CS229 YouTube | https://www.youtube.com/playlist?list=PLoROMvodv4rMiGQp3WXShtMGgzqpfVfbU | Advanced | Free',
    ],
    'mlops': [
      'Coursera: MLOps Specialization (DeepLearning.AI) | https://www.coursera.org/specializations/machine-learning-engineering-for-production-mlops | Intermediate | \$49/mo',
      'MLOps Community Slack | https://mlops.community | Community | Free',
      'Made With ML (Goku Mohandas) | https://madewithml.com | Intermediate | Free',
    ],
    'aws': [
      'Udemy: AWS Certified ML Specialty (Stephane Maarek) | https://www.udemy.com/course/aws-machine-learning | Advanced | ₹499-\$15',
      'AWS Skill Builder: ML Learning Plan | https://skillbuilder.aws | All levels | Free',
      'A Cloud Guru: AWS ML Specialty | https://www.pluralsight.com/cloud-guru | Advanced | \$35/mo',
    ],
    'gcp': [
      'Google Cloud Skills Boost: ML Engineer Path | https://www.cloudskillsboost.google/paths/17 | Intermediate | Free + labs paid',
      'Coursera: GCP Professional ML Engineer | https://www.coursera.org/professional-certificates/gcp-machine-learning | Advanced | \$49/mo',
    ],
    'azure': [
      'Microsoft Learn: AI-102 Azure AI Engineer | https://learn.microsoft.com/en-us/credentials/certifications/azure-ai-engineer | Intermediate | Free learning',
    ],
    'llm': [
      'DeepLearning.AI: Short Courses on LLMs | https://www.deeplearning.ai/short-courses | Intermediate | Free',
      'Hugging Face NLP Course | https://huggingface.co/learn/nlp-course | Intermediate | Free',
      'Andrej Karpathy: Let\'s build GPT (YouTube) | https://www.youtube.com/watch?v=kCc8FmEb1nY | Advanced | Free',
    ],
    'llm fine-tuning': [
      'DeepLearning.AI: Finetuning Large Language Models | https://www.deeplearning.ai/short-courses/finetuning-large-language-models | Intermediate | Free',
      'Hugging Face PEFT library docs | https://huggingface.co/docs/peft | Advanced | Free',
    ],
    'prompt engineering': [
      'DeepLearning.AI: ChatGPT Prompt Engineering for Developers | https://www.deeplearning.ai/short-courses/chatgpt-prompt-engineering-for-developers | Beginner | Free',
      'Anthropic Prompt Engineering docs | https://docs.anthropic.com/en/docs/prompt-engineering | Intermediate | Free',
    ],
    'nlp': [
      'Stanford CS224N NLP with Deep Learning | https://web.stanford.edu/class/cs224n | Advanced | Free',
      'Hugging Face NLP Course | https://huggingface.co/learn/nlp-course | Intermediate | Free',
      'fast.ai NLP Course | https://www.fast.ai/posts/2019-07-08-fastai-nlp.html | Intermediate | Free',
    ],
    'computer vision': [
      'Stanford CS231N CNN for Visual Recognition | http://cs231n.stanford.edu | Advanced | Free',
      'Coursera: Deep Learning Specialization Course 4 (CNN) | https://www.coursera.org/learn/convolutional-neural-networks | Intermediate | \$49/mo',
      'PyImageSearch tutorials | https://pyimagesearch.com | All levels | Free + paid books',
    ],
    'pytorch': [
      'PyTorch official tutorials | https://pytorch.org/tutorials | All levels | Free',
      'Daniel Bourke: PyTorch for Deep Learning | https://www.learnpytorch.io | Beginner | Free',
    ],
    'tensorflow': [
      'TensorFlow: Developer Certificate prep | https://www.tensorflow.org/certificate | Intermediate | \$100 exam',
      'Coursera: TensorFlow Developer Professional Cert | https://www.coursera.org/professional-certificates/tensorflow-in-practice | Intermediate | \$49/mo',
    ],
    'data science': [
      'Coursera: IBM Data Science Professional Certificate | https://www.coursera.org/professional-certificates/ibm-data-science | Beginner | \$49/mo',
      'Kaggle Courses (free, built-in notebooks) | https://www.kaggle.com/learn | All levels | Free',
      'DataCamp: Data Scientist with Python track | https://www.datacamp.com | Beginner | \$13-29/mo',
    ],
    'kubernetes': [
      'CNCF: Kubernetes Fundamentals (LFS258) | https://training.linuxfoundation.org/training/kubernetes-fundamentals | Intermediate | \$299',
      'KubeAcademy by VMware | https://kube.academy | All levels | Free',
    ],
    'docker': [
      'Docker official tutorial | https://docs.docker.com/get-started | Beginner | Free',
      'Udemy: Docker Mastery (Bret Fisher) | https://www.udemy.com/course/docker-mastery | Intermediate | ₹499-\$15',
    ],
    'sql': [
      'Mode Analytics: SQL Tutorial | https://mode.com/sql-tutorial | Beginner | Free',
      'SQLZoo interactive exercises | https://sqlzoo.net | Beginner | Free',
    ],
    'spark': [
      'Databricks Academy: Apache Spark Developer Associate | https://www.databricks.com/learn/certification/apache-spark-developer-associate | Intermediate | \$200 exam',
    ],
    'transformers': [
      'Hugging Face Transformers docs | https://huggingface.co/docs/transformers | Intermediate | Free',
      'The Illustrated Transformer (Jay Alammar) | https://jalammar.github.io/illustrated-transformer | Intermediate | Free',
    ],
    'rag': [
      'DeepLearning.AI: Building Systems with RAG | https://www.deeplearning.ai/short-courses | Intermediate | Free',
      'LangChain docs: Retrieval | https://python.langchain.com/docs/tutorials/rag | Intermediate | Free',
    ],
    'generative ai': [
      'Coursera: Generative AI with LLMs (DeepLearning.AI + AWS) | https://www.coursera.org/learn/generative-ai-with-llms | Intermediate | Free audit',
      'DeepLearning.AI Generative AI short courses | https://www.deeplearning.ai/short-courses | All levels | Free',
    ],
    'interview prep': [
      'LeetCode: ML Interview section | https://leetcode.com/discuss/interview-question | All levels | Free + \$35/mo premium',
      'Chip Huyen: ML Interviews book | https://huyenchip.com/ml-interviews-book | All levels | Free online',
      'Grokking the ML Interview (Educative) | https://www.educative.io/courses/grokking-the-machine-learning-interview | Intermediate | \$59/mo',
    ],
    'system design': [
      'Grokking the System Design Interview | https://www.educative.io/courses/grokking-the-system-design-interview | Intermediate | \$59/mo',
      'System Design Primer (GitHub) | https://github.com/donnemartin/system-design-primer | All levels | Free',
      'ByteByteGo YouTube | https://www.youtube.com/@ByteByteGo | All levels | Free',
    ],
  };

  /// Country-specific community resources to suggest in career plans
  static String communitiesFor(String country) {
    final c = country.toLowerCase();
    if (c.contains('india')) {
      return 'Analytics Vidhya (https://www.analyticsvidhya.com) · PyData Bangalore (Meetup) · TDWI India · Kaggle India';
    }
    if (c.contains('united kingdom') || c.contains('uk')) {
      return 'London AI/ML Meetup · AI Tech North · PyData London · UKBlackTech';
    }
    if (c.contains('united states') || c.contains('usa')) {
      return 'MLOps Community Slack · AI Tinkerers · Deep Learning NYC · LatinX in AI';
    }
    if (c.contains('germany')) {
      return 'PyData Berlin · ML Meetup Berlin · KI Bundesverband';
    }
    if (c.contains('canada')) {
      return 'Vector Institute events · Mila Montreal · Toronto Machine Learning Summit';
    }
    if (c.contains('australia')) {
      return 'Sydney Machine Learning Meetup · Melbourne ML · CSIRO Data61 events';
    }
    return 'Kaggle forums · Hugging Face Discord · MLOps Community Slack · Papers With Code Discord';
  }
}
