import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:math' as math;

/// Test script to verify image extraction from FIT room pages
Future<void> main() async {
  // Test multiple rooms to verify the logic works for all
  final testUrls = [
    'https://www.fit.vut.cz/fit/room/L314/.en',      // Has "Photo from the examination period"
    'https://www.fit.vut.cz/fit/room/D0203/.en',     // Technology Room
    'https://www.fit.vut.cz/fit/room/E112/.en',       // Lecture Room
  ];
  
  const separator = '============================================================';
  const dashSeparator = '------------------------------------------------------------';
  
  print('🧪 Testing Image Extraction for FIT Room Pages\n');
  print(separator);
  
  int successCount = 0;
  int totalImages = 0;
  
  for (var i = 0; i < testUrls.length; i++) {
    final testUrl = testUrls[i];
    final roomName = testUrl.split('/').last.replaceAll('.en', '');
    print('\n📸 Test ${i + 1}/${testUrls.length}: Room $roomName');
    print(dashSeparator);
    
    final photoUrls = await extractRoomPhotos(testUrl);
    
    if (photoUrls.isEmpty) {
      print('❌ No images found');
    } else {
      successCount++;
      totalImages += photoUrls.length;
      print('✅ Found ${photoUrls.length} image(s):');
      for (var j = 0; j < photoUrls.length; j++) {
        print('  ${j + 1}. ${photoUrls[j]}');
      }
    }
    
    // Small delay between requests
    if (i < testUrls.length - 1) {
      await Future.delayed(Duration(seconds: 1));
    }
  }
  
  print('\n$separator');
  print('📊 SUMMARY');
  print(separator);
  print('✅ Successful extractions: $successCount/${testUrls.length}');
  print('🖼️  Total images found: $totalImages');
  print(separator);
}

Future<List<String>> extractRoomPhotos(String roomUrl) async {
  try {
    print('Fetching room page: $roomUrl');
    
    // Make HTTP request with headers and timeout
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(roomUrl));
    request.headers.addAll({
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    });
    
    final response = await client
        .send(request)
        .timeout(Duration(seconds: 15))
        .then((streamedResponse) => http.Response.fromStream(streamedResponse));
    
    client.close();
    
    if (response.statusCode != 200) {
      print('❌ Failed to fetch room page: ${response.statusCode}');
      return [];
    }

    final htmlContent = response.body;
    print('✅ Successfully fetched HTML (${htmlContent.length} bytes)');
    
    final photoUrls = <String>[];
    
    // Helper function to convert relative URLs to absolute
    String convertToAbsoluteUrl(String src) {
      if (src.startsWith('http://') || src.startsWith('https://')) {
        return src;
      } else if (src.startsWith('//')) {
        return 'https:$src';
      } else if (src.startsWith('/')) {
        return 'https://www.fit.vut.cz$src';
      } else {
        return 'https://www.fit.vut.cz/$src';
      }
    }
    
    // Helper function to add photo URL if valid
    void addPhotoUrl(String? src) {
      if (src != null && src.isNotEmpty && 
          !src.contains('data:image') && 
          !src.contains('spacer') &&
          !src.contains('pixel') &&
          !src.contains('1x1') &&
          !src.contains('transparent') &&
          // Accept images with common extensions OR from fit.vut.cz domain
          (src.endsWith('.jpg') || src.endsWith('.jpeg') || src.endsWith('.png') ||
           src.endsWith('.webp') || src.endsWith('.gif') || 
           src.contains('fit.vut.cz') || src.contains('/fit/') ||
           src.contains('room') || src.contains('photo'))) {
        final absoluteUrl = convertToAbsoluteUrl(src).trim();
        if (!photoUrls.contains(absoluteUrl)) {
          photoUrls.add(absoluteUrl);
          print('  ✓ Found photo URL: $absoluteUrl');
        }
      }
    }
    
  // First, try using regex to find images after Photo heading
  // Look for headings that contain "Photo" (not just exactly "Photo")
  final photoSectionPatterns = [
    RegExp(r'<h3[^>]*>\s*Photo[^<]*</h3>', caseSensitive: false), // Exact "Photo"
    RegExp(r'<h3[^>]*>[^<]*Photo[^<]*</h3>', caseSensitive: false), // Contains "Photo"
    RegExp(r'<h4[^>]*>[^<]*Photo[^<]*</h4>', caseSensitive: false), // h4 with Photo
    RegExp(r'<h2[^>]*>[^<]*Photo[^<]*</h2>', caseSensitive: false), // h2 with Photo
  ];
  
  // Search for ALL photo sections (there might be multiple)
  for (final pattern in photoSectionPatterns) {
    final photoSectionMatches = pattern.allMatches(htmlContent);
    for (final photoSectionMatch in photoSectionMatches) {
      print('Found Photo heading, searching for images...');
      
      final photoSectionStart = photoSectionMatch.end;
      final photoSectionContent = htmlContent.substring(photoSectionStart);
      
      final nextSectionPattern = RegExp(
        r'<h[1-6][^>]*>|</section>',
        caseSensitive: false,
      );
      final nextSectionMatch = nextSectionPattern.firstMatch(photoSectionContent);
      
      final searchLimit = nextSectionMatch != null
          ? math.min(nextSectionMatch.start, 20000)
          : math.min(photoSectionContent.length, 20000);
      final photoSection = photoSectionContent.substring(0, searchLimit);
      
      final imgPatterns = [
        RegExp(r'<img[^>]*src\s*=\s*"([^"]+)"', caseSensitive: false),
        RegExp(r"<img[^>]*src\s*=\s*'([^']+)'", caseSensitive: false),
        RegExp(r'<img[^>]*src\s*=\s*([^\s>]+)', caseSensitive: false),
        RegExp(r'<img[^>]*data-src\s*=\s*"([^"]+)"', caseSensitive: false),
        RegExp(r"<img[^>]*data-src\s*=\s*'([^']+)'", caseSensitive: false),
        RegExp(r'<img[^>]*data-src\s*=\s*([^\s>]+)', caseSensitive: false),
      ];
      
      for (final imgPattern in imgPatterns) {
        final matches = imgPattern.allMatches(photoSection);
        for (final match in matches) {
          final photoUrl = match.group(1);
          addPhotoUrl(photoUrl);
        }
      }
    }
  }
    
    // Fallback: search all images if no Photo section found
    if (photoUrls.isEmpty) {
      print('No Photo section found, searching all images on page...');
      final document = html_parser.parse(htmlContent);
      final allImages = document.querySelectorAll('img');
      print('Found ${allImages.length} total img tags');
      for (final img in allImages) {
        addPhotoUrl(img.attributes['src']);
        addPhotoUrl(img.attributes['data-src']);
      }
    }
    
    print('Extracted ${photoUrls.length} photo URL(s)');
    return photoUrls;
  } catch (e) {
    print('❌ Error: $e');
    return [];
  }
}

