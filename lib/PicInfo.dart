class PicInfo {
  String? title;
  String? pic_id;
  int? height;
  int? width;
  String pic_url;
  String? video_url;

  PicInfo({
    this.title,
    required this.pic_url,
    this.video_url,
    this.pic_id,
    this.height,
    this.width,
  });
// Item({this.id, this.title, this.coverUrl});
}
