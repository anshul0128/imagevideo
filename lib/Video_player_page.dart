import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class VideoPlayerPage extends StatefulWidget {
  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  List<dynamic> _categories = [];
  List<dynamic> _filteredCategories = [];
  List<dynamic> _videos = [];
  bool _isLoading = true;
  bool _isCategorySelected = false;
  final String apiKey = 'ZDPQKnEQFalmVWt0SxwZngudT1Wv2ILLgVJkUs6lqQMYWcGdbuf2D7Fg';
  VideoPlayerController? _controller;
  String? _currentVideoUrl;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    // Simulated categories (Pexels API doesn't provide categories directly, so these are assumed)
    _categories = ['Nature',
      'Abstract',
      'Technology',
      'Mountains',
      'Cars',
      'Bikes',
      'People',];
    _filteredCategories = _categories;
    setState(() {
      _isLoading = false;
    });
  }

  void _filterCategories(String query) {
    if (query.isEmpty) {
      _filteredCategories = _categories;
    } else {
      _filteredCategories = _categories
          .where((category) => category.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    setState(() {});
  }

  Future<void> _fetchVideos(String category) async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.get(
      Uri.parse('https://api.pexels.com/videos/search?query=$category'),
      headers: {
        'Authorization': apiKey,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _videos = data['videos'];
      setState(() {
        _isLoading = false;
        _isCategorySelected = true;
      });
    } else {
      throw Exception('Failed to load videos');
    }
  }

  void _playVideo(String videoUrl) {
    if (_controller != null) {
      _controller!.dispose();
    }
    _controller = VideoPlayerController.network(videoUrl)
      ..initialize().then((_) {
        setState(() {
          _controller!.play();
          _currentVideoUrl = videoUrl;
        });
      });
  }

  Future<void> _downloadVideo(String videoUrl) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final response = await http.get(Uri.parse(videoUrl));
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory?.path}/${videoUrl.split('/').last}';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video downloaded to $filePath')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission denied')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pexels Video Player'),
        leading: _isCategorySelected || _controller != null
            ? IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_controller != null) {
              _controller!.dispose();
              _controller = null;
              setState(() {
                _currentVideoUrl = null;
              });
            } else {
              setState(() {
                _isCategorySelected = false;
                _videos = [];
              });
            }
          },
        )
            : null,
      ),
      body: _isLoading
          ? Center(child: SpinKitFadingCircle(color: Colors.blue, size: 50.0))
          : Column(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_controller!),
                  _ControlsOverlay(
                    controller: _controller!,
                    onDownload: () {
                      _downloadVideo(_currentVideoUrl!);
                    },
                  ),
                  VideoProgressIndicator(_controller!, allowScrubbing: true),
                ],
              ),
            ),
          if (!_isCategorySelected)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Categories',
                  border: OutlineInputBorder(),
                ),
                onChanged: (query) {
                  _filterCategories(query);
                },
              ),
            ),
          Expanded(
            child: _isCategorySelected
                ? VideoGrid(
              videos: _videos,
              onSelectVideo: (videoUrl) {
                _playVideo(videoUrl);
              },
              onDownloadVideo: (videoUrl) {
                _downloadVideo(videoUrl);
              },
            )
                : CategoryList(
              categories: _filteredCategories,
              onSelectCategory: (category) {
                _fetchVideos(category);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryList extends StatelessWidget {
  final List<dynamic> categories;
  final Function(String) onSelectCategory;

  CategoryList({required this.categories, required this.onSelectCategory});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.all(10.0),
          child: ListTile(
            title: Text(
              categories[index],
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              onSelectCategory(categories[index]);
            },
          ),
        );
      },
    );
  }
}

class VideoGrid extends StatelessWidget {
  final List<dynamic> videos;
  final Function(String) onSelectVideo;
  final Function(String) onDownloadVideo;

  VideoGrid({
    required this.videos,
    required this.onSelectVideo,
    required this.onDownloadVideo,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        mainAxisSpacing: 4.0,
        crossAxisSpacing: 4.0,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final videoUrl = video['video_files'][0]['link'];
        final imageUrl = video['image'];
        return GestureDetector(
          onTap: () {
            onSelectVideo(videoUrl);
          },
          child: Stack(
            children: [
              Image.network(imageUrl, fit: BoxFit.cover),
              Positioned(
                bottom: 8.0,
                right: 8.0,
                child: IconButton(
                  icon: Icon(Icons.download, color: Colors.white),
                  onPressed: () {
                    onDownloadVideo(videoUrl);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({Key? key, required this.controller, required this.onDownload}) : super(key: key);

  static const _playbackIcons = [
    Icons.play_arrow,
    Icons.pause,
  ];

  final VideoPlayerController controller;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 20),
            reverseDuration: const Duration(milliseconds: 200),
            child: controller.value.isPlaying
                ? const SizedBox.shrink()
                : Container(
              color: Colors.black26,
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 100.0,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 9.0,
          right: 10.0,

          child: IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: onDownload,
          ),
        ),
      ],
    );
  }
}
