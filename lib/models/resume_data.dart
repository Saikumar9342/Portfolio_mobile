import 'portfolio_data.dart';

class ResumeData {
  String name;
  String email;
  String phone;
  String summary;
  String location;
  List<Education> education;
  List<Experience> experience;
  List<Project> projects;
  Map<String, List<String>> skills;
  List<String> certifications;
  List<String> languages;

  ResumeData({
    required this.name,
    required this.email,
    required this.phone,
    required this.summary,
    required this.location,
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
      email: '',
      phone: '',
      summary: '',
      location: '',
      education: [],
      experience: [],
      projects: [],
      skills: {},
      certifications: [],
      languages: [],
    );
  }
}
