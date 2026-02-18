import 'portfolio_data.dart';

class ResumeData {
  String name;
  String role;
  String email;
  String personalEmail;
  String phone;
  String summary;
  String location;
  Map<String, dynamic> hero;
  Map<String, dynamic> about;
  Map<String, dynamic> expertise;
  List<Education> education;
  List<Experience> experience;
  List<Project> projects;
  Map<String, dynamic> skills;
  List<String> certifications;
  List<String> languages;

  ResumeData({
    required this.name,
    this.role = '',
    required this.email,
    this.personalEmail = '',
    required this.phone,
    required this.summary,
    required this.location,
    this.hero = const {},
    this.about = const {},
    this.expertise = const {},
    required this.education,
    required this.experience,
    required this.projects,
    required this.skills,
    required this.certifications,
    required this.languages,
  });

  factory ResumeData.empty() {
    return ResumeData(
      name: '',
      role: '',
      email: '',
      personalEmail: '',
      phone: '',
      summary: '',
      location: '',
      hero: {},
      about: {},
      expertise: {},
      education: [],
      experience: [],
      projects: [],
      skills: {},
      certifications: [],
      languages: [],
    );
  }
}
