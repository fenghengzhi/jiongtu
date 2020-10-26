import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'CustomCacheManager.dart';
import 'DetailScreen.dart';
import 'Resource.dart';
import 'PicInfo.dart';

class _BaseListState extends State<BaseList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<Resource> _resources = [];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
        onRefresh: widget.getListData,
        child: Scrollbar(
            child: StaggeredGridView.countBuilder(
          physics: BouncingScrollPhysics(),
          crossAxisCount: 2,
          itemCount: _resources.length,
//        mainAxisSpacing: 4.0,
          crossAxisSpacing: 0,
          itemBuilder: (BuildContext context, int index) => _Item(
              resource: _resources[index], getItemData: widget.getItemData),
          staggeredTileBuilder: (int index) => StaggeredTile.fit(1),
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
}

abstract class BaseList extends StatefulWidget {
  @override
  _BaseListState createState() => _BaseListState();

  // 获取囧图列表
  // @override
  @protected
  Future<List<Resource>> getListData() async {
    return null;
  }

  // 获取某一篇囧图的内容列表
  // @override
  @protected
  Future<List<PicInfo>> getItemData(Resource resource) async {
    return null;
  }
}

class _Item extends StatelessWidget {
  final Resource resource;
  final Future<List<PicInfo>> Function(Resource) getItemData;

  _Item({@required this.resource, @required this.getItemData});

  @override
  Widget build(BuildContext context) => FlatButton(
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
      ]));
}
