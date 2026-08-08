# Frontend Build Guide — Module 1 / Member 3 (Complete)
**Feature:** Producer product listings with media, production time, comments, reviews, and upvote/downvote
**Stack:** Flutter (Dart), calling an Express.js REST API, JWT auth
**Based on:** your "Flow 1" Figma concept map (Home → Add Item → Your Items → Item Details), extended with the pieces the assignment requires that the mockup doesn't show yet

This version specs out **every** screen and widget end to end, including full code for the parts that weren't in the original prototype (media upload, production time, comments, reviews, upvote/downvote), styled to match your existing tan/grey design system.

---

## 1. Screen map

```
Home ──► Add Item ──► (posts) ──► Your Items ──► Item Details
  ▲                                    ▲               │
  └────────────────────────────────────┴───────────────┘
              shared bottom nav on all 4 screens
```

- **Home** — producer dashboard: avatar, name, stat grid
- **Add Item** — create a listing: existing 5 fields + media upload + production time
- **Your Items** — producer's own listings
- **Item Details** — media carousel, info cards, vote row, comments, reviews

---

## 2. Design system

```dart
// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFEAEAEA);
  static const surface = Colors.white;
  static const inputFill = Color(0xFFB98A5E);   // tan/caramel
  static const cardFill = Color(0xFFD9D9D9);    // light grey card
  static const accent = Color(0xFFB98A5E);
  static const dark = Colors.black;
  static const textMuted = Color(0xFF6B6B6B);
  static const upvoteActive = Color(0xFF2E7D32);
  static const downvoteActive = Color(0xFFC62828);
}
```

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

final appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.background,
  fontFamily: 'Inter', // or leave default if you haven't bundled a font
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: Colors.white70),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ),
);
```

---

## 3. Packages (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  provider: ^6.1.2
  image_picker: ^1.1.2
  video_player: ^2.9.1
  chewie: ^1.8.5
  cached_network_image: ^3.4.1
  carousel_slider: ^5.0.0
  intl: ^0.19.0
  flutter_secure_storage: ^9.2.2
  timeago: ^3.7.0
  uuid: ^4.5.1          # for temp local ids while optimistically rendering new comments/reviews
```

---

## 4. Data models (`lib/models/`)

```dart
// listing.dart
enum ProductionTimeType { instant, scheduled }

class Listing {
  final String id;
  final String producerId;
  final String assetName;
  final String category;
  final double fundingTarget;
  final double rentalPrice;
  final String description;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final ProductionTimeType productionTimeType;
  final int? productionDays;
  final String status;
  final String campaignStatus;
  final double fundingProgressPercent;
  final int investorCount;
  final String specifications;
  final int upvotes;
  final int downvotes;
  final VoteType myVote; // this user's current vote, none/up/down
  final DateTime createdAt;

  const Listing({
    required this.id,
    required this.producerId,
    required this.assetName,
    required this.category,
    required this.fundingTarget,
    required this.rentalPrice,
    required this.description,
    required this.imageUrls,
    required this.videoUrls,
    required this.productionTimeType,
    this.productionDays,
    required this.status,
    required this.campaignStatus,
    required this.fundingProgressPercent,
    required this.investorCount,
    required this.specifications,
    required this.upvotes,
    required this.downvotes,
    this.myVote = VoteType.none,
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'],
        producerId: j['producerId'],
        assetName: j['assetName'],
        category: j['category'],
        fundingTarget: (j['fundingTarget'] as num).toDouble(),
        rentalPrice: (j['rentalPrice'] as num).toDouble(),
        description: j['description'] ?? '',
        imageUrls: List<String>.from(j['imageUrls'] ?? []),
        videoUrls: List<String>.from(j['videoUrls'] ?? []),
        productionTimeType: j['productionTimeType'] == 'instant'
            ? ProductionTimeType.instant
            : ProductionTimeType.scheduled,
        productionDays: j['productionDays'],
        status: j['status'] ?? '',
        campaignStatus: j['campaignStatus'] ?? '',
        fundingProgressPercent:
            (j['fundingProgressPercent'] as num?)?.toDouble() ?? 0,
        investorCount: j['investorCount'] ?? 0,
        specifications: j['specifications'] ?? '',
        upvotes: j['upvotes'] ?? 0,
        downvotes: j['downvotes'] ?? 0,
        myVote: _voteFromString(j['myVote']),
        createdAt: DateTime.parse(j['createdAt']),
      );

  Map<String, dynamic> toCreateJson() => {
        'assetName': assetName,
        'category': category,
        'fundingTarget': fundingTarget,
        'rentalPrice': rentalPrice,
        'description': description,
        'imageUrls': imageUrls,
        'videoUrls': videoUrls,
        'productionTimeType':
            productionTimeType == ProductionTimeType.instant ? 'instant' : 'scheduled',
        'productionDays': productionDays,
      };
}

enum VoteType { none, up, down }

VoteType _voteFromString(String? s) {
  switch (s) {
    case 'up':
      return VoteType.up;
    case 'down':
      return VoteType.down;
    default:
      return VoteType.none;
  }
}
```

```dart
// comment.dart
class Comment {
  final String id;
  final String listingId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final Comment? reply; // producer's single reply, if any

  const Comment({
    required this.id,
    required this.listingId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.reply,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'],
        listingId: j['listingId'],
        authorId: j['authorId'],
        authorName: j['authorName'],
        text: j['text'],
        createdAt: DateTime.parse(j['createdAt']),
        reply: j['reply'] != null ? Comment.fromJson(j['reply']) : null,
      );
}
```

```dart
// review.dart
class Review {
  final String id;
  final String listingId;
  final String investorId;
  final String investorName;
  final String text;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.listingId,
    required this.investorId,
    required this.investorName,
    required this.text,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'],
        listingId: j['listingId'],
        investorId: j['investorId'],
        investorName: j['investorName'],
        text: j['text'],
        createdAt: DateTime.parse(j['createdAt']),
      );
}
```

```dart
// home_stats.dart
class HomeStats {
  final int gigsCompleted;
  final int gigsCurrentlyListed;
  final int investors;
  final double rating;

  const HomeStats({
    required this.gigsCompleted,
    required this.gigsCurrentlyListed,
    required this.investors,
    required this.rating,
  });

  factory HomeStats.fromJson(Map<String, dynamic> j) => HomeStats(
        gigsCompleted: j['gigsCompleted'] ?? 0,
        gigsCurrentlyListed: j['gigsCurrentlyListed'] ?? 0,
        investors: j['investors'] ?? 0,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
      );
}
```

---

## 5. Services (`lib/services/`)

```dart
// api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const _baseUrl = 'https://your-backend.example.com/api';
  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$_baseUrl$path'), headers: await _headers());
    return _handle(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }
}
```

```dart
// listing_service.dart
import '../models/listing.dart';
import '../models/comment.dart';
import '../models/review.dart';
import 'api_client.dart';

class ListingService {
  final ApiClient _api = ApiClient();

  Future<List<Listing>> getMyListings(String producerId) async {
    final data = await _api.get('/producers/$producerId/listings');
    return (data as List).map((j) => Listing.fromJson(j)).toList();
  }

  Future<Listing> getListing(String id) async {
    final data = await _api.get('/listings/$id');
    return Listing.fromJson(data);
  }

  Future<Listing> createListing(Map<String, dynamic> payload) async {
    final data = await _api.post('/listings', payload);
    return Listing.fromJson(data);
  }

  Future<void> vote(String listingId, String type) =>
      _api.post('/listings/$listingId/vote', {'type': type});

  Future<List<Comment>> getComments(String listingId) async {
    final data = await _api.get('/listings/$listingId/comments');
    return (data as List).map((j) => Comment.fromJson(j)).toList();
  }

  Future<Comment> postComment(String listingId, String text) async {
    final data = await _api.post('/listings/$listingId/comments', {'text': text});
    return Comment.fromJson(data);
  }

  Future<Comment> postReply(String commentId, String text) async {
    final data = await _api.post('/comments/$commentId/reply', {'text': text});
    return Comment.fromJson(data);
  }

  Future<List<Review>> getReviews(String listingId) async {
    final data = await _api.get('/listings/$listingId/reviews');
    return (data as List).map((j) => Review.fromJson(j)).toList();
  }

  Future<bool> canReview(String listingId) async {
    final data = await _api.get('/listings/$listingId/can-review');
    return data['canReview'] == true;
  }

  Future<Review> postReview(String listingId, String text) async {
    final data = await _api.post('/listings/$listingId/reviews', {'text': text});
    return Review.fromJson(data);
  }
}
```

---

## 6. Providers (`lib/providers/`)

```dart
// auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? userId;
  String? role; // 'producer' | 'investor' | 'renter' | 'admin'
  String? name;

  Future<void> loadFromStorage() async {
    userId = await _storage.read(key: 'userId');
    role = await _storage.read(key: 'role');
    name = await _storage.read(key: 'name');
    notifyListeners();
  }

  bool get isProducer => role == 'producer';
  bool get isInvestor => role == 'investor';
}
```

```dart
// listing_provider.dart
import 'package:flutter/foundation.dart';
import '../models/listing.dart';
import '../models/comment.dart';
import '../models/review.dart';
import '../services/listing_service.dart';

class ListingProvider extends ChangeNotifier {
  final _service = ListingService();

  Listing? listing;
  List<Comment> comments = [];
  List<Review> reviews = [];
  bool canReview = false;
  bool loading = false;

  Future<void> loadListing(String id) async {
    loading = true;
    notifyListeners();
    listing = await _service.getListing(id);
    comments = await _service.getComments(id);
    reviews = await _service.getReviews(id);
    canReview = await _service.canReview(id);
    loading = false;
    notifyListeners();
  }

  Future<void> vote(VoteType type) async {
    if (listing == null) return;
    final prev = listing!.myVote;
    final typeStr = type == VoteType.up ? 'up' : 'down';
    // optimistic update
    listing = _applyVoteLocally(listing!, type);
    notifyListeners();
    try {
      await _service.vote(listing!.id, typeStr);
    } catch (_) {
      listing = _applyVoteLocally(listing!, prev); // roll back on failure
      notifyListeners();
    }
  }

  Listing _applyVoteLocally(Listing l, VoteType newVote) {
    int up = l.upvotes, down = l.downvotes;
    if (l.myVote == VoteType.up) up--;
    if (l.myVote == VoteType.down) down--;
    if (newVote == VoteType.up) up++;
    if (newVote == VoteType.down) down++;
    return Listing(
      id: l.id, producerId: l.producerId, assetName: l.assetName, category: l.category,
      fundingTarget: l.fundingTarget, rentalPrice: l.rentalPrice, description: l.description,
      imageUrls: l.imageUrls, videoUrls: l.videoUrls, productionTimeType: l.productionTimeType,
      productionDays: l.productionDays, status: l.status, campaignStatus: l.campaignStatus,
      fundingProgressPercent: l.fundingProgressPercent, investorCount: l.investorCount,
      specifications: l.specifications, upvotes: up, downvotes: down, myVote: newVote,
      createdAt: l.createdAt,
    );
  }

  Future<void> addComment(String text) async {
    final c = await _service.postComment(listing!.id, text);
    comments = [c, ...comments];
    notifyListeners();
  }

  Future<void> addReply(String commentId, String text) async {
    final replied = await _service.postReply(commentId, text);
    comments = comments.map((c) => c.id == commentId ? replied : c).toList();
    notifyListeners();
  }

  Future<void> addReview(String text) async {
    final r = await _service.postReview(listing!.id, text);
    reviews = [r, ...reviews];
    notifyListeners();
  }
}
```

```dart
// home_stats_provider.dart
import 'package:flutter/foundation.dart';
import '../models/home_stats.dart';
import '../services/api_client.dart';

class HomeStatsProvider extends ChangeNotifier {
  final _api = ApiClient();
  HomeStats? stats;
  bool loading = false;

  Future<void> load(String producerId) async {
    loading = true;
    notifyListeners();
    final data = await _api.get('/producers/$producerId/stats');
    stats = HomeStats.fromJson(data);
    loading = false;
    notifyListeners();
  }
}
```

Wire these up once in `main.dart`:

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadFromStorage()),
        ChangeNotifierProvider(create: (_) => ListingProvider()),
        ChangeNotifierProvider(create: (_) => HomeStatsProvider()),
      ],
      child: MaterialApp(theme: appTheme, home: const HomeScreen()),
    ),
  );
}
```

---

## 7. Reusable widgets (`lib/widgets/`)

### 7.1 Shared bottom nav

```dart
// app_bottom_nav.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex; // 0 Home, 1 (FAB) Add Items, 2 Your Items
  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.home_outlined, 'Home', 0, '/home'),
          const SizedBox(width: 48), // space for FAB
          _navItem(context, Icons.work_outline, 'Your Items', 2, '/producer/items'),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext ctx, IconData icon, String label, int index, String route) {
    final active = index == currentIndex;
    return InkWell(
      onTap: () => Navigator.pushReplacementNamed(ctx, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? Colors.black : Colors.grey),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.black : Colors.grey)),
        ],
      ),
    );
  }
}

// Use in each screen's Scaffold:
// floatingActionButton: FloatingActionButton(
//   backgroundColor: Colors.black,
//   shape: const CircleBorder(),
//   onPressed: () => Navigator.pushNamed(context, '/producer/items/create'),
//   child: const Icon(Icons.add, color: Colors.white),
// ),
// floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
// bottomNavigationBar: AppBottomNav(currentIndex: 0),
```

### 7.2 Reusable info card (Funding Progress / Investors / Specifications)

```dart
// info_card.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final Widget child; // subtitle text, progress bar, list, etc.
  const InfoCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
```

### 7.3 Media picker (Add Item — missing piece)

```dart
// media_picker.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';

class PickedMedia {
  final File file;
  final bool isVideo;
  PickedMedia(this.file, this.isVideo);
}

class MediaPicker extends StatefulWidget {
  final ValueChanged<List<PickedMedia>> onChanged;
  const MediaPicker({super.key, required this.onChanged});

  @override
  State<MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  final List<PickedMedia> _items = [];
  final _picker = ImagePicker();

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage();
    setState(() => _items.addAll(files.map((f) => PickedMedia(File(f.path), false))));
    widget.onChanged(_items);
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _items.add(PickedMedia(File(file.path), true)));
      widget.onChanged(_items);
    }
  }

  void _remove(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos / Videos', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < _items.length; i++) _thumb(i),
              _addButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumb(int i) {
    final item = _items[i];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black12,
              image: item.isVideo
                  ? null
                  : DecorationImage(image: FileImage(item.file), fit: BoxFit.cover),
            ),
            child: item.isVideo ? const Icon(Icons.videocam, size: 32) : null,
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _remove(i),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black87,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton() {
    return Row(children: [
      InkWell(
        onTap: _pickImages,
        child: Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_a_photo, color: Colors.white),
        ),
      ),
      const SizedBox(width: 8),
      InkWell(
        onTap: _pickVideo,
        child: Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.video_call, color: Colors.white),
        ),
      ),
    ]);
  }
}
```

Uploading: on `Post`, loop over `_items`, upload each `File` via `multipart/form-data` to `/api/uploads`, collect returned URLs, then include them in the listing's `imageUrls`/`videoUrls` before calling `createListing`. Ask your backend teammate whether they want one multipart request per file or a single batched request — either works, just agree on it.

### 7.4 Production time selector (Add Item — missing piece)

```dart
// production_time_selector.dart
import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';

class ProductionTimeSelector extends StatefulWidget {
  final void Function(ProductionTimeType type, int? days) onChanged;
  const ProductionTimeSelector({super.key, required this.onChanged});

  @override
  State<ProductionTimeSelector> createState() => _ProductionTimeSelectorState();
}

class _ProductionTimeSelectorState extends State<ProductionTimeSelector> {
  ProductionTimeType _type = ProductionTimeType.instant;
  final _daysController = TextEditingController();

  void _emit() {
    final days = _type == ProductionTimeType.scheduled
        ? int.tryParse(_daysController.text)
        : null;
    widget.onChanged(_type, days);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Production Time', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          ChoiceChip(
            label: const Text('Instant'),
            selected: _type == ProductionTimeType.instant,
            selectedColor: AppColors.inputFill,
            onSelected: (_) {
              setState(() => _type = ProductionTimeType.instant);
              _emit();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('N days'),
            selected: _type == ProductionTimeType.scheduled,
            selectedColor: AppColors.inputFill,
            onSelected: (_) {
              setState(() => _type = ProductionTimeType.scheduled);
              _emit();
            },
          ),
        ]),
        if (_type == ProductionTimeType.scheduled) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Number of days'),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}
```

Small badge for Item Details:

```dart
// production_time_badge.dart
import 'package:flutter/material.dart';
import '../models/listing.dart';

class ProductionTimeBadge extends StatelessWidget {
  final ProductionTimeType type;
  final int? days;
  const ProductionTimeBadge({super.key, required this.type, this.days});

  @override
  Widget build(BuildContext context) {
    final label = type == ProductionTimeType.instant ? 'Instant' : 'Delivered in $days days';
    return Chip(label: Text(label), backgroundColor: Colors.black12);
  }
}
```

### 7.5 Vote row (Item Details — missing piece)

```dart
// vote_row.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../providers/listing_provider.dart';
import '../theme/app_colors.dart';

class VoteRow extends StatelessWidget {
  const VoteRow({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    final listing = provider.listing!;
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.thumb_up,
              color: listing.myVote == VoteType.up ? AppColors.upvoteActive : Colors.grey),
          onPressed: () => context.read<ListingProvider>().vote(
              listing.myVote == VoteType.up ? VoteType.none : VoteType.up),
        ),
        Text('${listing.upvotes}'),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(Icons.thumb_down,
              color: listing.myVote == VoteType.down ? AppColors.downvoteActive : Colors.grey),
          onPressed: () => context.read<ListingProvider>().vote(
              listing.myVote == VoteType.down ? VoteType.none : VoteType.down),
        ),
        Text('${listing.downvotes}'),
      ],
    );
  }
}
```

*(Note: toggling back to `VoteType.none` on a second tap is a UX nicety — confirm with your backend whether "un-voting" is supported; if not, just let a new vote overwrite the old one and drop the toggle-off behavior.)*

### 7.6 Media carousel (Item Details — missing piece)

```dart
// media_carousel.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class MediaCarousel extends StatelessWidget {
  final List<String> imageUrls;
  final List<String> videoUrls;
  const MediaCarousel({super.key, required this.imageUrls, required this.videoUrls});

  @override
  Widget build(BuildContext context) {
    final items = [...imageUrls.map((u) => _ImageItem(u)), ...videoUrls.map((u) => _VideoItem(u))];
    if (items.isEmpty) {
      return Container(height: 220, color: Colors.black12,
          child: const Icon(Icons.image_not_supported, size: 48));
    }
    return CarouselSlider(
      options: CarouselOptions(height: 220, enlargeCenterPage: true, viewportFraction: 0.9),
      items: items.map((it) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: it,
      )).toList(),
    );
  }
}

class _ImageItem extends StatelessWidget {
  final String url;
  const _ImageItem(this.url);
  @override
  Widget build(BuildContext context) =>
      CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity,
          placeholder: (_, __) => Container(color: Colors.black12),
          errorWidget: (_, __, ___) => Container(color: Colors.black12, child: const Icon(Icons.broken_image)));
}

class _VideoItem extends StatefulWidget {
  final String url;
  const _VideoItem(this.url);
  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late VideoPlayerController _video;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {
          _chewie = ChewieController(videoPlayerController: _video, autoPlay: false, looping: false);
        });
      });
  }

  @override
  void dispose() {
    _video.dispose();
    _chewie?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _chewie == null ? Container(color: Colors.black12) : Chewie(controller: _chewie!);
}
```

### 7.7 Comment section (Item Details — missing piece)

```dart
// comment_tile.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../models/comment.dart';
import '../providers/auth_provider.dart';
import '../providers/listing_provider.dart';

class CommentTile extends StatefulWidget {
  final Comment comment;
  const CommentTile({super.key, required this.comment});

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _replying = false;
  final _replyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isProducer = context.watch<AuthProvider>().isProducer;
    final c = widget.comment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(c.text),
          Text(timeago.format(c.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (c.reply != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Producer reply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(c.reply!.text),
                  ],
                ),
              ),
            ),
          if (isProducer && c.reply == null)
            _replying
                ? Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: const InputDecoration(hintText: 'Write a reply...'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: () {
                        if (_replyController.text.trim().isEmpty) return;
                        context.read<ListingProvider>().addReply(c.id, _replyController.text.trim());
                        setState(() => _replying = false);
                      },
                    ),
                  ])
                : TextButton(
                    onPressed: () => setState(() => _replying = true),
                    child: const Text('Reply'),
                  ),
        ],
      ),
    );
  }
}
```

```dart
// comment_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import 'comment_tile.dart';
import 'info_card.dart';

class CommentSection extends StatefulWidget {
  const CommentSection({super.key});
  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final comments = context.watch<ListingProvider>().comments;
    return InfoCard(
      title: 'Comments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comments.isEmpty) const Text('No comments yet.', style: TextStyle(color: Colors.grey)),
          for (final c in comments) CommentTile(comment: c),
          const Divider(),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Add a comment...'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                if (_controller.text.trim().isEmpty) return;
                context.read<ListingProvider>().addComment(_controller.text.trim());
                _controller.clear();
              },
            ),
          ]),
        ],
      ),
    );
  }
}
```

### 7.8 Review section (Item Details — missing piece, investor-gated)

```dart
// review_section.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import 'info_card.dart';

class ReviewSection extends StatefulWidget {
  const ReviewSection({super.key});
  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    return InfoCard(
      title: 'Reviews',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.reviews.isEmpty)
            const Text('No reviews yet.', style: TextStyle(color: Colors.grey)),
          for (final r in provider.reviews)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.investorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(r.text),
                  Text(timeago.format(r.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          const Divider(),
          // Gated: only investors who actually invested in THIS listing can leave a review.
          // provider.canReview comes from the backend — never compute this client-side.
          if (provider.canReview)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'Leave a review...'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (_controller.text.trim().isEmpty) return;
                  context.read<ListingProvider>().addReview(_controller.text.trim());
                  _controller.clear();
                },
              ),
            ])
          else
            const Text(
              'Only investors who have invested in this item can leave a review.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
```

---

## 8. Screens (`lib/screens/`)

### 8.1 Home screen

```dart
// home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/home_stats_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (auth.userId != null) context.read<HomeStatsProvider>().load(auth.userId!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final statsProvider = context.watch<HomeStatsProvider>();
    final stats = statsProvider.stats;

    return Scaffold(
      body: SafeArea(
        child: statsProvider.loading || stats == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text('Ekota Builder', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    const CircleAvatar(radius: 40, backgroundColor: Colors.black12, child: Icon(Icons.person, size: 40)),
                    const SizedBox(height: 8),
                    Text(auth.name ?? 'User Name'),
                    const SizedBox(height: 40),
                    _statGrid(stats),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        onPressed: () => Navigator.pushNamed(context, '/producer/items/create'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _statGrid(stats) {
    Widget box(String value, String label) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        box(stats.gigsCompleted.toString().padLeft(2, '0'), 'Gigs Completed'),
        box(stats.gigsCurrentlyListed.toString().padLeft(2, '0'), 'Gigs Currently Listed'),
      ]),
      Row(children: [
        box(stats.investors.toString().padLeft(2, '0'), 'Investors'),
        box(stats.rating.toStringAsFixed(1), 'Rating'),
      ]),
    ]);
  }
}
```

### 8.2 Add Item screen

```dart
// add_item_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../providers/listing_provider.dart';
import '../services/listing_service.dart';
import '../widgets/media_picker.dart';
import '../widgets/production_time_selector.dart';
import '../widgets/app_bottom_nav.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});
  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetName = TextEditingController();
  final _category = TextEditingController();
  final _fundingTarget = TextEditingController();
  final _rentalPrice = TextEditingController();
  final _description = TextEditingController();

  List<PickedMedia> _media = [];
  ProductionTimeType _prodType = ProductionTimeType.instant;
  int? _prodDays;
  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one photo or video')));
      return;
    }
    if (_prodType == ProductionTimeType.scheduled && _prodDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter number of production days')));
      return;
    }

    setState(() => _submitting = true);
    try {
      // TODO: upload each file in _media to /api/uploads, collect URLs
      final imageUrls = <String>[]; // fill from upload responses
      final videoUrls = <String>[];

      final listing = await ListingService().createListing({
        'assetName': _assetName.text.trim(),
        'category': _category.text.trim(),
        'fundingTarget': double.tryParse(_fundingTarget.text) ?? 0,
        'rentalPrice': double.tryParse(_rentalPrice.text) ?? 0,
        'description': _description.text.trim(),
        'imageUrls': imageUrls,
        'videoUrls': videoUrls,
        'productionTimeType': _prodType == ProductionTimeType.instant ? 'instant' : 'scheduled',
        'productionDays': _prodDays,
      });

      if (mounted) Navigator.pushReplacementNamed(context, '/listings/${listing.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Item'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Asset Name', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(controller: _assetName, validator: _required),
              const SizedBox(height: 16),

              const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(controller: _category, validator: _required),
              const SizedBox(height: 16),

              const Text('Funding Target', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(controller: _fundingTarget, keyboardType: TextInputType.number, validator: _required),
              const SizedBox(height: 16),

              const Text('Rental Price', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(controller: _rentalPrice, keyboardType: TextInputType.number, validator: _required),
              const SizedBox(height: 16),

              const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(controller: _description, maxLines: 3, validator: _required),
              const SizedBox(height: 20),

              MediaPicker(onChanged: (m) => setState(() => _media = m)),
              const SizedBox(height: 20),

              ProductionTimeSelector(onChanged: (type, days) {
                _prodType = type;
                _prodDays = days;
              }),
              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
```

### 8.3 Your Items screen

```dart
// your_items_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/listing.dart';
import '../providers/auth_provider.dart';
import '../services/listing_service.dart';
import '../widgets/app_bottom_nav.dart';

class YourItemsScreen extends StatefulWidget {
  const YourItemsScreen({super.key});
  @override
  State<YourItemsScreen> createState() => _YourItemsScreenState();
}

class _YourItemsScreenState extends State<YourItemsScreen> {
  late Future<List<Listing>> _future;

  @override
  void initState() {
    super.initState();
    final producerId = context.read<AuthProvider>().userId!;
    _future = ListingService().getMyListings(producerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Items'), backgroundColor: Colors.transparent, elevation: 0),
      body: FutureBuilder<List<Listing>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('No items yet. Tap + to add one.'));
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return InkWell(
                onTap: () => Navigator.pushNamed(context, '/listings/${item.id}'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.assetName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Status: ${item.status}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.imageUrls.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrls.first, height: 140, width: double.infinity, fit: BoxFit.cover,
                                placeholder: (_, __) => Container(height: 140, color: Colors.black12))
                            : Container(height: 140, color: Colors.black12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        onPressed: () => Navigator.pushNamed(context, '/producer/items/create'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
```

### 8.4 Item Details screen

```dart
// item_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import '../widgets/media_carousel.dart';
import '../widgets/production_time_badge.dart';
import '../widgets/vote_row.dart';
import '../widgets/info_card.dart';
import '../widgets/comment_section.dart';
import '../widgets/review_section.dart';
import '../widgets/app_bottom_nav.dart';

class ItemDetailsScreen extends StatefulWidget {
  final String listingId;
  const ItemDetailsScreen({super.key, required this.listingId});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ListingProvider>().loadListing(widget.listingId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    final listing = provider.listing;

    return Scaffold(
      appBar: AppBar(title: const Text('Item Details'), backgroundColor: Colors.transparent, elevation: 0),
      body: provider.loading || listing == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                MediaCarousel(imageUrls: listing.imageUrls, videoUrls: listing.videoUrls),
                const SizedBox(height: 16),
                Text(listing.assetName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Center(child: Text('Campaign Status: ${listing.campaignStatus}',
                    style: const TextStyle(color: Colors.grey))),
                const SizedBox(height: 8),
                Center(child: ProductionTimeBadge(type: listing.productionTimeType, days: listing.productionDays)),
                const SizedBox(height: 12),
                const Center(child: VoteRow()),
                const SizedBox(height: 20),

                InfoCard(
                  title: 'Funding Progress',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: listing.fundingProgressPercent / 100),
                      const SizedBox(height: 4),
                      Text('${listing.fundingProgressPercent.toStringAsFixed(0)}% funded'),
                    ],
                  ),
                ),
                InfoCard(title: 'Investors', child: Text('${listing.investorCount} investors')),
                InfoCard(title: 'Specifications', child: Text(listing.specifications)),

                const SizedBox(height: 8),
                const CommentSection(),
                const ReviewSection(),
              ],
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
```

---

## 9. Routing (`main.dart`)

```dart
MaterialApp(
  theme: appTheme,
  initialRoute: '/home',
  routes: {
    '/home': (_) => const HomeScreen(),
    '/producer/items': (_) => const YourItemsScreen(),
    '/producer/items/create': (_) => const AddItemScreen(),
  },
  onGenerateRoute: (settings) {
    final uri = Uri.parse(settings.name ?? '');
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'listings') {
      return MaterialPageRoute(
        builder: (_) => ItemDetailsScreen(listingId: uri.pathSegments[1]),
      );
    }
    return null;
  },
)
```

---

## 10. API contract to hand off to your backend teammates

| Action | Method | Endpoint |
|---|---|---|
| Get producer home stats | `GET` | `/api/producers/:id/stats` |
| Get producer's listings | `GET` | `/api/producers/:id/listings` |
| Create listing | `POST` | `/api/listings` |
| Upload media | `POST` | `/api/uploads` (multipart) |
| Get listing detail | `GET` | `/api/listings/:id` |
| Vote on listing | `POST` | `/api/listings/:id/vote` — `{type: "up"|"down"}` |
| Get comments | `GET` | `/api/listings/:id/comments` |
| Post comment | `POST` | `/api/listings/:id/comments` — `{text}` |
| Post reply (producer only) | `POST` | `/api/comments/:id/reply` — `{text}` |
| Get reviews | `GET` | `/api/listings/:id/reviews` |
| Check review eligibility | `GET` | `/api/listings/:id/can-review` — `{canReview: bool}` |
| Post review (investor only) | `POST` | `/api/listings/:id/reviews` — `{text}` |

All calls carry `Authorization: Bearer <JWT>`, handled centrally in `ApiClient`.

---

## 11. Folder structure (final)

```
lib/
  theme/
    app_colors.dart
    app_theme.dart
  models/
    listing.dart
    comment.dart
    review.dart
    home_stats.dart
  services/
    api_client.dart
    listing_service.dart
  providers/
    auth_provider.dart
    listing_provider.dart
    home_stats_provider.dart
  screens/
    home_screen.dart
    add_item_screen.dart
    your_items_screen.dart
    item_details_screen.dart
  widgets/
    app_bottom_nav.dart
    info_card.dart
    media_picker.dart
    production_time_selector.dart
    production_time_badge.dart
    vote_row.dart
    media_carousel.dart
    comment_tile.dart
    comment_section.dart
    review_section.dart
  main.dart
```

---

## 12. Build order

1. Theme (`app_colors.dart`, `app_theme.dart`) + `ApiClient` + `AppBottomNav` + `InfoCard`
2. Models + `ListingService` (code against mock JSON if backend isn't ready yet)
3. Providers, wired up in `main.dart`
4. **Home** screen (uses `HomeStatsProvider`)
5. **Your Items** screen (uses `ListingService.getMyListings`)
6. **Add Item** screen: the five base fields first, then drop in `MediaPicker` and `ProductionTimeSelector`
7. **Item Details** static layout with the three original cards
8. Add `MediaCarousel` + `ProductionTimeBadge` + `VoteRow`
9. Add `CommentSection` (list + post + producer reply)
10. Add `ReviewSection` (list + gated post, driven by `canReview` from the backend)
11. Swap every mock data source for live API calls
12. Polish: loading skeletons, empty states, error snackbars, pull-to-refresh on Your Items / Item Details

---

## 13. Things to confirm with your team before/while building

- Exact JSON field names for every endpoint in Section 10 (the ones here are reasonable guesses)
- Whether un-voting (tap the same vote again to remove it) is supported by the backend, or votes are one-way
- Whether category is a fixed list (dropdown) or free text
- How review eligibility (`can-review`) is computed server-side — you just need the boolean, but know what triggers it
- Whether comments are open to any signed-in role or restricted (the requirements doc only restricts who can *reply* — producer — and who can *review* — invested investors)
