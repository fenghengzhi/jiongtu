import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'CustomCacheManager.dart';
import 'DetailScreen.dart';
import 'PicInfo.dart';
import 'Resource.dart';

class _BaseListState extends State<BaseList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<Resource> _resources = [];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (kDebugMode) {
      print(_resources);
    }
    return RefreshIndicator(
        onRefresh: refresh,
        child: Scrollbar(
            child: MasonryGridView.count(
          physics: BouncingScrollPhysics(),
          crossAxisCount: 2,
          itemCount: _resources.length,
//        mainAxisSpacing: 4.0,
          crossAxisSpacing: 0,
          itemBuilder: (BuildContext context, int index) => _Item(
              resource: _resources[index], getItemData: widget.getItemData),
          // staggeredTileBuilder: (int index) => StaggeredTile.fit(1),
        )));
  }

  @override
  void initState() {
    super.initState();
    widget.getListData().then((resources) {
      setState(() {
        _resources = resources;
      });
    });
  }

  Future<void> refresh() async {
    final resources = await widget.getListData();
    setState(() {
      _resources = resources;
    });
  }
}

abstract class BaseList extends StatefulWidget {
  @override
  _BaseListState createState() => _BaseListState();

  // 获取囧图列表
  // @override
  @protected
  Future<List<Resource>> getListData();

  // 获取某一篇囧图的内容列表
  // @override
  @protected
  Future<List<PicInfo>> getItemData(Resource resource);
}

class _Item extends StatelessWidget {
  final Resource resource;
  final Future<List<PicInfo>> Function(Resource) getItemData;

  _Item({required this.resource, required this.getItemData});

  @override
  Widget build(BuildContext context) => TextButton(
      onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  DetailScreen(resource: resource, getItemData: getItemData))),
    child: Column(children: [
        CachedNetworkImage(
          fit: BoxFit.fitWidth,
          imageUrl: resource.coverUrl,
          cacheManager: CustomCacheManager.instance,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
        Text(resource.title)
      ]),
  );
}
