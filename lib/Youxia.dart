import 'dart:convert';

import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

import 'BaseList.dart';
import 'PicInfo.dart';
import 'Resource.dart';

class Youxia extends BaseList {
  @override
  Future<List<Resource>> getListData() async {
    final url = Uri.parse(
        'https://api3.ali213.net/feedearn/readarticlelist?token=&mid=22&page=1&v=1');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      final List<dynamic> article = jsonBody['data']['article'];
      final resources = article.map((item) {
        return Resource(
            title: item['Title'], coverUrl: item['PicPath'], id: item['ID']);
      }).toList();
      return resources;
    } else {
      throw Exception('Failed to load post');
    }
  }

  Future<List<PicInfo>> getItemData(Resource resource) async {
    final url = Uri.parse(
        'https://3g.ali213.net/app/news/newsdetailN?v=1&id=${resource.id}&token=');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      final document = parse(jsonBody['Content']);
      final imgs = document.querySelectorAll('img.yx-fs-img');
      // debugger();
      final picInfos = imgs.map((img) {
        final parent =
            img.parent?.localName == 'p' ? img.parent : img.parent?.parent;
        final next =
            (parent?.nextElementSibling?.nextElementSibling?.text.isNotEmpty ==
                    true)
                ? parent!.nextElementSibling!.nextElementSibling
                : parent?.nextElementSibling;
        final title = (next != null) ? next.text : '';
        // final next = parent.
        return PicInfo(
          // title: img.parent.parent.nextElementSibling.text != null
          //     ? img.parent.parent.nextElementSibling.text
          //     : img.parent.parent.nextElementSibling.nextElementSibling.text,
          title: title,
          pic_url: img.attributes['data-original'] ?? '',
        );
      }).toList();
      return picInfos;
    } else {
      throw Exception('Failed to load post');
    }
  }
}
