class HeroData {
  String badge;
  String title;
  String subtitle;
  String cta;
  String secondaryCta;

  HeroData({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.secondaryCta,
  });

  factory HeroData.fromMap(Map<String, dynamic> map) {
    return HeroData(
      badge: map['badge'] ?? '',
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      cta: map['cta'] ?? '',
      secondaryCta: map['secondaryCta'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'badge': badge,
      'title': title,
      'subtitle': subtitle,
      'cta': cta,
      'secondaryCta': secondaryCta,
    };
  }
}

class AboutData {
  String title;
  String biography;
  String location;
  List<Education> education;

  AboutData({
    required this.title,
    required this.biography,
    required this.location,
    required this.education,
  });

  factory AboutData.fromMap(Map<String, dynamic> map) {
    return AboutData(
      title: map['title'] ?? '',
      biography: map['biography'] ?? '',
      location: map['location'] ?? '',
      education:
          (map['education'] as List<dynamic>?)
              ?.map((e) => Education.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'biography': biography,
      'location': location,
      'education': education.map((e) => e.toMap()).toList(),
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
  List<String> techStack;
  String imageUrl;
  String liveLink;
  String githubLink;
  DateTime? createdAt;

  Project({
    required this.id,
    required this.title,
    required this.description,
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
      'techStack': techStack,
      'imageUrl': imageUrl,
      'liveLink': liveLink,
      'githubLink': githubLink,
      'createdAt': createdAt,
    };
  }
}
