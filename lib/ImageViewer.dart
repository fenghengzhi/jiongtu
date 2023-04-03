import 'package:cached_network_image/cached_network_image.dart';

// import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
// import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:share_plus/share_plus.dart';

import 'CustomCacheManager.dart';
import 'PicInfo.dart';

class ImageViewer extends StatelessWidget {
  final PicInfo _picInfo;

  ImageViewer(this._picInfo);

  @override
  Widget build(BuildContext context) =>
      // Scaffold(appBar: AppBar(), body: _Viewer(_picInfo));
      Scaffold(appBar: AppBar(), body: _Viewer(_picInfo));
}

class _ViewerState extends State<_Viewer> {
  double _scale = 1.0;
  double _startScale = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  double _startOffsetX = 0.0;
  double _startOffsetY = 0.0;

  Offset _startFocal = Offset.zero;

  Offset _origin = const Offset(0, 0);
  final GlobalKey _key = GlobalKey();
  double width = 1.0;
  double height = 1.0;

  @override
  void initState() {
    super.initState();
    // debugger();
    final _picInfo = widget._picInfo;
    final _width = _picInfo.width;
    final _height = _picInfo.height;

    if (_width != null && _width > 0 && _height != null && _height > 0) {
      width = _width.toDouble();
      height = _height.toDouble();
    } else {
      CustomCacheManager.instance.getSingleFile(_picInfo.pic_url).then((file) {
        final image = Image.file(file);

        image.image
            .resolve(const ImageConfiguration())
            .addListener(new ImageStreamListener((ImageInfo info, bool _) {
          setState(() {
            width = info.image.width.toDouble();
            height = info.image.height.toDouble();
          });
          // m.width = info.image.width;
          // m.height = info.image.height;
          // this.sendMsg(m);
        }));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.black,
        child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.center,
            child: Container(
                width: width,
                height: height,
                transform: Matrix4.identity()
                  ..translate((1 - _scale) * _origin.dx + _offsetX,
                      (1 - _scale) * _origin.dy + _offsetY)
                  ..scale(_scale),
                child: GestureDetector(
                    // onDoubleTap: _doubleTapHandler,
                    onScaleUpdate: scaleUpdateHandler,
                    onScaleStart: _scaleStartHandler,
                    onLongPressStart: _saveToGallery,
                    child: CachedNetworkImage(
                        key: _key,
                        fit: BoxFit.fitWidth,
                        cacheManager: CustomCacheManager.instance,
                        errorWidget: (context, url, error) => Icon(Icons.error),
//                            width: double.infinity,
//                            height: double.infinity,
                        imageUrl: widget._picInfo.pic_url)))));
//                            imageUrl:
//                                'https://via.placeholder.com/100x100'))))));
  }

  // _doubleTapHandler() {
  // FocusScope.of(context).requestFocus(FocusNode());
  // this._openInWebview(
  //     'http://www.duowan.com/mComment/index.html?domain=tu.duowan.com&uniqid=${_picInfo.cmt_md5}&url=/');
  // }

  _scaleStartHandler(ScaleStartDetails details) {
    final RenderObject? renderBox = _key.currentContext?.findRenderObject();

    if (renderBox != null && renderBox is RenderBox) {
      final leftTop = renderBox.localToGlobal(Offset.zero);
      final origin =
          (details.focalPoint - leftTop) / _scale; //点击的像素距图片左上角坐标（换算成scale=1下）
//    print(origin);
      _offsetX = _offsetX + (origin.dx - _origin.dx) * (_scale - 1.0);

      _offsetY = _offsetY + (origin.dy - _origin.dy) * (_scale - 1.0);

      _origin = origin;
      _startOffsetX = _offsetX;
      _startOffsetY = _offsetY;
      _startScale = _scale;

      _startFocal = details.focalPoint;
    }
  }

  scaleUpdateHandler(ScaleUpdateDetails details) {
    setState(() {
      _scale = details.scale * _startScale;
      _offsetX = details.focalPoint.dx - _startFocal.dx + _startOffsetX;
      _offsetY = details.focalPoint.dy - _startFocal.dy + _startOffsetY;
    });
  }

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

  _saveToGallery(LongPressStartDetails details) async {
    final file = await CustomCacheManager.instance
        .getSingleFile(widget._picInfo.pic_url);
//    final result = await ImageGallerySaver.save(file.readAsBytesSync());
    Share.shareXFiles([XFile(file.path)]);
  }
}

class _Viewer extends StatefulWidget {
  final PicInfo _picInfo;

  _Viewer(this._picInfo);

  @override
  _ViewerState createState() => _ViewerState();
}
