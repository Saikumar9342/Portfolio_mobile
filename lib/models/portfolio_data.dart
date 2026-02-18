class HeroData {
  String badge;
  String title;
  String subtitle;
  String cta;
  String secondaryCta;
  String imageUrl;

  HeroData({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.secondaryCta,
    this.imageUrl = '',
  });

  factory HeroData.fromMap(Map<String, dynamic> map) {
    return HeroData(
      badge: map['badge'] ?? '',
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      cta: map['cta'] ?? '',
      secondaryCta: map['secondaryCta'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'badge': badge,
      'title': title,
      'subtitle': subtitle,
      'cta': cta,
      'secondaryCta': secondaryCta,
      'imageUrl': imageUrl,
    };
  }
}

class AboutData {
  String title;
  String biography;
  String location;
  String resumeUrl; // Added resumeUrl
  List<Education> education;
  List<Experience> experience;

  AboutData({
    required this.title,
    required this.biography,
    required this.location,
    this.resumeUrl = '',
    required this.education,
    required this.experience,
  });

  factory AboutData.fromMap(Map<String, dynamic> map) {
    return AboutData(
      title: map['title'] ?? '',
      biography: map['biography'] ?? '',
      location: map['location'] ?? '',
      resumeUrl: map['resumeUrl'] ?? '',
      education: (map['education'] as List<dynamic>?)
              ?.map((e) => Education.fromMap(e))
              .toList() ??
          [],
      experience: (map['experience'] as List<dynamic>?)
              ?.map((e) => Experience.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'biography': biography,
      'location': location,
      'resumeUrl': resumeUrl,
      'education': education.map((e) => e.toMap()).toList(),
      'experience': experience.map((e) => e.toMap()).toList(),
    };
  }
}

class Education {
  String degree;
  String institution;
  String year;

  Education({
    required this.degree,
    required this.institution,
    required this.year,
  });

  factory Education.fromMap(Map<String, dynamic> map) {
    return Education(
      degree: map['degree'] ?? '',
      institution: map['institution'] ?? '',
      year: map['year'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'degree': degree, 'institution': institution, 'year': year};
  }
}

class Experience {
  String position;
  String company;
  String startDate;
  String endDate;
  String description;

  Experience({
    required this.position,
    required this.company,
    required this.startDate,
    required this.endDate,
    required this.description,
  });

  factory Experience.fromMap(Map<String, dynamic> map) {
    return Experience(
      position: map['position'] ?? '',
      company: map['company'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'company': company,
      'startDate': startDate,
      'endDate': endDate,
      'description': description,
    };
  }
}

class ContactData {
  String title;
  String description;
  String email;
  String cta;
  String secondaryCta;

  ContactData({
    required this.title,
    required this.description,
    required this.email,
    required this.cta,
    required this.secondaryCta,
  });

  factory ContactData.fromMap(Map<String, dynamic> map) {
    return ContactData(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      email: map['email'] ?? '',
      cta: map['cta'] ?? '',
      secondaryCta: map['secondaryCta'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'email': email,
      'cta': cta,
      'secondaryCta': secondaryCta,
    };
  }
}

class Project {
  String id;
  String title;
  String description;
  String fullDescription;
  String role;
  String category;
  List<String> techStack;
  String imageUrl;
  String liveLink;
  String githubLink;
  DateTime? createdAt;

  Project({
    required this.id,
    required this.title,
    required this.description,
    this.fullDescription = '',
    this.role = '',
    this.category = '',
    required this.techStack,
    required this.imageUrl,
    required this.liveLink,
    required this.githubLink,
    this.createdAt,
  });

  factory Project.fromMap(String id, Map<String, dynamic> map) {
    return Project(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      fullDescription: map['fullDescription'] ?? '',
      role: map['role'] ?? '',
      category: map['category'] ?? '',
      techStack: List<String>.from(map['techStack'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      liveLink: map['liveLink'] ?? '',
      githubLink: map['githubLink'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'fullDescription': fullDescription,
      'role': role,
      'category': category,
      'techStack': techStack,
      'imageUrl': imageUrl,
      'liveLink': liveLink,
      'githubLink': githubLink,
      'createdAt': createdAt,
    };
  }
}
