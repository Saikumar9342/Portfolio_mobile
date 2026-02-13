import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DataSeeder {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seedAllData() async {
    try {
      debugPrint('Starting database seed...');

      // 1. HERO SECTION
      await _db.collection('content').doc('hero').set({
        'title': "HI, I'M SAIKUMAR PASUMARTHI",
        'subtitle':
            "Associate Software Engineer (2 years). I build high-performance applications with Flutter, React, Node.js, and Cloud technologies.",
        'badge': "Available for Work",
        'cta': "View Work",
        'secondaryCta': "Contact Me",
      });
      debugPrint('Hero section updated.');

      // 2. ABOUT SECTION
      await _db.collection('content').doc('about').set({
        'title': "About SAIKUMAR PASUMARTHI",
        'biography':
            "I am a passionate Associate Software Engineer with over 2 years of experience. I specialize in building scalable web and mobile applications using modern frameworks like Flutter and React. Based in Hyderabad, I love solving complex problems with clean code.",
        'location': "Hyderabad, India",
        'education': [
          {
            "degree": "B.Tech in Computer Science",
            "institution": "Your University Name",
            "year": "2020 - 2024"
          }
        ],
        'interests': [
          "Mobile Development",
          "Cloud Architecture",
          "UI/UX Design"
        ],
      });
      debugPrint('About section updated.');

      // 3. SKILLS SECTION
      await _db.collection('content').doc('skills').set({
        'frontendTitle': "Frontend Engineering",
        'mobileTitle': "Mobile Development",
        'backendTitle': "Cloud & Backend",
        'toolsTitle': "Workflow & Tools",
        'frameworksTitle': "Toolbox",
        'frontend': [
          {'name': "React", 'level': 90},
          {'name': "HTML/CSS", 'level': 95},
          {'name': "TypeScript", 'level': 85},
          {'name': "Next.js", 'level': 80},
        ],
        'mobile': ["Flutter", "React Native", "iOS", "Android"],
        'backend': ["Node.js", "Firebase", "Supabase", "SQL"],
        'tools': ["Git", "VS Code", "Figma", "Postman"],
        'frameworks': ["TailwindCSS", "Material UI", "Riverpod"],
      });
      debugPrint('Skills section updated.');

      // 4. EXPERTISE SECTION
      await _db.collection('content').doc('expertise').set({
        'title': "My Expertise",
        'label': "WHAT I DO",
        'stats': [
          {"label": "Years of Experience", "value": "2+"},
          {"label": "Projects Completed", "value": "15+"},
          {"label": "Happy Clients", "value": "10+"},
        ],
        'services': [
          {
            "id": "immersive",
            "title": "Mobile Development",
            "description":
                "Building high-performance, cross-platform mobile applications using Flutter.",
          },
          {
            "id": "visual",
            "title": "Web Development",
            "description":
                "Creating responsive, modern, and SEO-friendly websites with React and Next.js.",
          },
          {
            "id": "motion",
            "title": "Backend Systems",
            "description":
                "Designing scalable backend architectures and API integrations.",
          },
        ],
      });
      debugPrint('Expertise section updated.');

      // 5. CONTACT SECTION
      await _db.collection('content').doc('contact').set({
        'title': "Get In Touch",
        'description':
            "Feel free to reach out for collaborations or just a friendly hello.",
        'email': "saikumar.p@finsolconsult.com",
        'personalEmail': "saikumarpasumarthi@gmail.com",
        'cta': "Send Message",
        'secondaryCta': "Download CV",
      });
      debugPrint('Contact section updated.');

      // 6. NAVBAR SECTION
      await _db.collection('content').doc('navbar').set({
        'logoText': "S",
        'ctaText': "Hire Me",
        'items': [
          {"label": "Home", "href": "/"},
          {"label": "Projects", "href": "/projects"},
          {"label": "Skills", "href": "/#skills"},
          {"label": "About", "href": "/#about"},
        ],
      });
      debugPrint('Navbar section updated.');

      // 7. PROJECTS (Deleting old ones first to avoid duplicates, optional)
      // Note: This deletes ALL projects. careful!
      final projects = await _db.collection('projects').get();
      for (var doc in projects.docs) {
        await doc.reference.delete();
      }
      debugPrint('Cleared old projects.');

      // Add New Projects
      final projectList = [
        {
          'title': 'Portfolio Website',
          'description':
              'A modern, responsive portfolio website built with Next.js 14, TypeScript, and Tailwind CSS. Features smooth animations with Framer Motion and a dynamic content management system using Firebase.',
          'techStack': [
            'Next.js',
            'React',
            'TypeScript',
            'Tailwind',
            'Firebase'
          ],
          'imageUrl':
              'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?q=80&w=1000&auto=format&fit=crop', // Placeholder
          'liveLink': 'https://saikumar.dev',
          'githubLink': 'https://github.com/saikumar/portfolio',
          'category': 'Web Development',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'E-Commerce Mobile App',
          'description':
              'A full-featured shopping application built with Flutter. Includes user authentication, product catalog, cart management, and Stripe payment gateway integration.',
          'techStack': ['Flutter', 'Firebase Auth', 'Stripe', 'Riverpod'],
          'imageUrl':
              'https://images.unsplash.com/photo-1556742049-0cfed4f7a07d?q=80&w=1000&auto=format&fit=crop',
          'liveLink': '',
          'githubLink': 'https://github.com/saikumar/ecommerce',
          'category': 'Mobile App',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Task Management Dashboard',
          'description':
              'A productivity tool for managing teams and tasks. Features drag-and-drop Kanban boards, real-time updates using WebSockets, and detailed analytics reports.',
          'techStack': ['React', 'Node.js', 'Socket.io', 'MongoDB'],
          'imageUrl':
              'https://images.unsplash.com/photo-1540350394557-8d14678e7f91?q=80&w=1000&auto=format&fit=crop',
          'liveLink': '',
          'githubLink': 'https://github.com/saikumar/task-manager',
          'category': 'Web App',
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      for (var p in projectList) {
        await _db.collection('projects').add(p);
      }
      debugPrint('Projects added.');

      debugPrint('DATABASE SEED COMPLETED SUCCESSFULLY!');
    } catch (e) {
      debugPrint('Error seeding database: $e');
    }
  }
}
