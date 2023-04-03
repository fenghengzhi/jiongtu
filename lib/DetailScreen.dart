// import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'CustomCacheManager.dart';
import 'ImageViewer.dart';
import 'PicInfo.dart';
import 'Resource.dart';
import 'VideoPlayer.dart';

class _DetailScreen extends State<DetailScreen> {
  List<PicInfo> _picInfos = [];

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(widget.resource.title),
      ),
      body: Scrollbar(
          child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _picInfos.length,
              itemBuilder: (context, i) => _Item(_picInfos[i]))));

  @override
  void initState() {
    super.initState();
    widget.getItemData(widget.resource).then((picInfos) async {
      setState(() {
        _picInfos = picInfos;
      });
      final __picInfos = (picInfos as List<PicInfo>);
      for (var i = 0; i < __picInfos.length; i++) {
        if (!this.mounted) {
          return;
        }
        while (true) {
          try {
            await CustomCacheManager.instance
                .getSingleFile(__picInfos[i].pic_url);
            break;
          } catch (e) {
            await Future.delayed(Duration(seconds: 1));
          }
        }
      }
    });
  }
}

class _Item extends StatelessWidget {
  const _Item(this.picInfo);

  final PicInfo picInfo;

  @override
  Widget build(BuildContext context) {
    final width = picInfo.width;
    final height = picInfo.height;
    return TextButton(
        onPressed: () {
          // print(picInfo.url);
          // print(picInfo.mp4_url);
          // print(picInfo.video_url);
          if (picInfo.video_url?.isNotEmpty == true) {
            // print('videoplayer');
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => VideoPlayer(picInfo)));
          } else {
            // print('iamgeviewer');
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => ImageViewer(picInfo)));
          }
        },
        child: Column(children: [
          // AspectRatio(
          // aspectRatio: picInfo.file_width / picInfo.file_height,
          // child:
          CachedNetworkImage(
              placeholder: (context, url) => AspectRatio(
                  aspectRatio:
                      (width != null && height != null) ? (width / height) : 1,
                  child: Center(child: CircularProgressIndicator())),
              errorWidget: (context, url, error) => AspectRatio(
                  aspectRatio:
                      (width != null && height != null) ? (width / height) : 1,
                  child: const Icon(Icons.error)),
              cacheManager: CustomCacheManager.instance,
              fit: BoxFit.fitWidth,
              width: double.infinity,
              imageUrl: picInfo.pic_url),
          // imageUrl: 'https://via.placeholder.com/1000x1000'),
          Center(child: Text(picInfo.title?.trim() ?? ''))
        ]));
  }
}

class DetailScreen extends StatefulWidget {
  final Resource resource;
  final Future<List<PicInfo>> Function(Resource) getItemData;

  DetailScreen({required this.resource, required this.getItemData});

  @override
  _DetailScreen createState() => _DetailScreen();
}
