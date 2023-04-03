import 'package:flutter/material.dart';

// import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
// import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:video_player/video_player.dart' as vp;

import 'PicInfo.dart';

class _VideoPlayerState extends State<VideoPlayer> {
  late vp.VideoPlayerController _controller;

//  bool _isPlaying = false;

  @override
  void deactivate() {
    super.deactivate();
    _controller.pause();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  void initState() {
    super.initState();
    final videoUrl = widget._picInfo.video_url;
    // print(_picInfo);

    // print(videoUrl);

    _controller = vp.VideoPlayerController.network(videoUrl ?? '')
      ..setLooping(true)
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        // _controller.play();
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(),
      body: Center(
          child: _controller.value.isInitialized
              ? GestureDetector(
                  onTap: _tapHandler,
                  // onDoubleTap: _doubleTapHandler,
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: vp.VideoPlayer(_controller),
                  ))
              : Container()));

  _tapHandler() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

// _doubleTapHandler() {
// FocusScope.of(context).requestFocus(FocusNode());
// _openInWebview(
//     'http://www.duowan.com/mComment/index.html?domain=tu.duowan.com&uniqid=${_picInfo.cmt_md5}&url=/');
// }

// _openInWebview(String url) async {
//   if (await url_launcher.canLaunch(url)) {
//     // print(url);
//     Navigator.push(
//         context,
//         MaterialPageRoute(
//             builder: (ctx) => WebviewScaffold(
//                   initialChild: Center(child: CircularProgressIndicator()),
//                   url: url,
//                   appBar: AppBar(title: Text(url)),
//                 )));
//   } else {
//     Scaffold.of(context).showSnackBar(
//       SnackBar(
//         content: Text('URL $url can not be launched.'),
//       ),
//     );
//   }
// }
}

class VideoPlayer extends StatefulWidget {
  final PicInfo _picInfo;

  VideoPlayer(this._picInfo);

  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}
