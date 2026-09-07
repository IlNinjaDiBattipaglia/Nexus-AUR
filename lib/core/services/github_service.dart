import 'dart:convert';
import 'package:http/http.dart' as http; // Assicurati di avere http nel pubspec.yaml se già usato, oppure usiamo dart:io

class GitHubReleaseModel {
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;

  GitHubReleaseModel({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
  });
}

class GitHubService {
  // Sostituisci con il tuo username/repository reale su GitHub
  static const String repoOwner = "IlNinjaDiBattipaglia"; 
  static const String repoName = "nexus_aur";

  static Future<GitHubReleaseModel?> getLatestRelease() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GitHubReleaseModel(
          tagName: data['tag_name'] ?? '',
          name: data['name'] ?? '',
          body: data['body'] ?? 'Nessun changelog disponibile.',
          htmlUrl: data['html_url'] ?? '',
        );
      }
    } catch (e) {
      // Gestione errori di rete
    }
    return null;
  }
}
