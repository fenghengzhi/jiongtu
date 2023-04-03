import 'dart:convert';

import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

import 'BaseList.dart';
import 'PicInfo.dart';
import 'Resource.dart';

class Youminxingkong extends BaseList {
  @override
  Future<List<Resource>> getListData() async {
    final url = Uri.parse('https://www.gamersky.com/ent/147/');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      // final jsonBody = json.decode(response.body);
      final doc = parse(response.body);
      final list = doc.querySelectorAll('.pictxt li');
      // final List<dynamic> article = jsonBody['data']['article'];
      final resources = list.map((item) {
        final href = item.querySelector('a')?.attributes['href'];
        // https://www.gamersky.com/ent/202010/1327669.shtml
        final exp = new RegExp(
            r"(?<=^https:\/\/www\.gamersky\.com\/(?:news|ent)\/\d*\/)(\d*)(?=.shtml$)");
        // debugger();
        return Resource(
            title: item.querySelector('.tc')?.text ?? '',
            coverUrl:
                item.querySelector('.img .pe_u_thumb')?.attributes['src'] ?? '',
            id: exp.stringMatch(href ?? '') ?? '');
      }).toList();
      return resources;
    } else {
      throw Exception('Failed to load post');
    }
  }

  Future<List<PicInfo>> getItemData(Resource resource) async {
    final url = Uri.parse('http://appapi2.gamersky.com/v5/getArticle');
    final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'osVersion': '7.1.2',
          'deviceId': '21893252224223313213378183165835',
          'appVersion': '5.8.0',
          'app': 'GSAPP',
          'os': 'android',
          'deviceType': 'vmos',
          'request': {
            'cacheMinutes': 10,
            'articleId': resource.id,
            'extraFiledNames': '',
            'appModelFieldNames': '',
            'modelFieldNames':
                'Tag,Tag_Index,pageNames,Title,Subheading,Author,pcPageURL,CopyFrom,UpdateTime,DefaultPicUrl,GameScore,GameLib,TitleIntact,NodeId,editor,Content_Index'
          }
        }));
    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body);
      // debugger();
      final document = parse(jsonBody['result'][0]['Content_Index']);

      final imgs = document.querySelectorAll('.GsImageLabel');
      // debugger();
      final picInfos = imgs
          .expand<PicInfo>((box) {
            final img = box.querySelector('.picact');
            if (img != null) {
              // box.nextElementSibling
              // if (img.attributes['src'] == null) debugger();
              if (img.attributes['original-image-width'] != null &&
                  img.attributes['original-image-height'] != null) {
                return [PicInfo(
                  title: box.text,
                  pic_url: img.attributes['src'] ?? '',
                  width:
                      int.parse(img.attributes['original-image-width'] ?? '0'),
                  height:
                      int.parse(img.attributes['original-image-height'] ?? '0'),
                )];
              } else {
                return [PicInfo(
                  title: box.text,
                  pic_url: img.attributes['src'] ?? '',
                )];
              }
            }
            final a = box.querySelector('a');
            if (a != null) {
              // https://www.gamersky.com/showimage/id_gamersky.shtml?https://img1.gamersky.com/image2020/10/20201010_ls_red_141_3/gamersky_02origin_03_2020101018233B0.jpg
              final exp = new RegExp(
                  r"(?<=^https:\/\/www\.gamersky\.com\/showimage\/id_gamersky\.shtml\?)([^]*)$");
              // if (exp.stringMatch(a.attributes['_cke_saved_href']) == null)
              //   debugger();

              return [PicInfo(
                title: box.text,
                pic_url: exp.stringMatch(a.attributes['_cke_saved_href'] != null
                        ? a.attributes['_cke_saved_href'] ?? ''
                        : a.attributes['href'] ?? '') ??
                    '',
              )];
            }
            return [];
          })
          .toList();
      return picInfos;
    } else {
      throw Exception('Failed to load post');
    }
  }
}
