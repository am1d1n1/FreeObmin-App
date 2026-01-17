import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';

class GitHubReleaseInfo {
  final String tagName;
  final String body;
  final String htmlUrl;
  final String? assetUrl;

  const GitHubReleaseInfo({
    required this.tagName,
    required this.body,
    required this.htmlUrl,
    this.assetUrl,
  });
}

class UpdateCheckResult {
  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;
  final String releaseNotes;
  final Uri releaseUrl;
  final Uri? downloadUrl;

  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.releaseNotes,
    required this.releaseUrl,
    this.downloadUrl,
  });
}

class GitHubUpdateService {
  final http.Client _client;

  GitHubUpdateService({http.Client? client}) : _client = client ?? http.Client();

  Future<UpdateCheckResult> checkForUpdate() async {
    final owner = AppConfig.githubUpdateOwner;
    final repo = AppConfig.githubUpdateRepo;
    if (owner.isEmpty || repo.isEmpty) {
      throw StateError('GitHub update owner/repo not configured');
    }

    final release = await _fetchLatestRelease(owner, repo);
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final latestVersion = _normalizeTag(release.tagName);
    final releaseUrl = Uri.tryParse(release.htmlUrl) ??
        Uri.https('github.com', '/$owner/$repo/releases');
    final downloadUrl = release.assetUrl != null ? Uri.tryParse(release.assetUrl!) : null;
    final updateAvailable =
        latestVersion.isNotEmpty && latestVersion != currentVersion;

    return UpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: latestVersion.isNotEmpty ? latestVersion : currentVersion,
      updateAvailable: updateAvailable,
      releaseNotes: release.body,
      releaseUrl: releaseUrl,
      downloadUrl: downloadUrl,
    );
  }

  Future<GitHubReleaseInfo> _fetchLatestRelease(String owner, String repo) async {
    final uri = Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');
    final response = await _client.get(uri, headers: {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'freeobmin-update-checker',
    });
    if (response.statusCode != 200) {
      throw Exception('GitHub release check failed (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawAssets = payload['assets'];
    String? downloadUrl;
    if (rawAssets is List) {
      for (final rawAsset in rawAssets) {
        if (rawAsset is Map<String, dynamic>) {
          final url = rawAsset['browser_download_url'] as String?;
          final name = rawAsset['name'] as String? ?? '';
          if (url != null && (name.endsWith('.apk') || url.endsWith('.apk'))) {
            downloadUrl = url;
            break;
          }
        }
      }
    }

    return GitHubReleaseInfo(
      tagName: payload['tag_name'] ?? '',
      body: (payload['body'] as String?) ?? '',
      htmlUrl: payload['html_url'] ?? '',
      assetUrl: downloadUrl,
    );
  }

  String _normalizeTag(String tag) {
    return tag.replaceAll(RegExp(r'[^0-9.]'), '').trim();
  }
}
