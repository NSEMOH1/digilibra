import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/ui/util/ui_util.dart';
import 'package:wallet/util/fileutil.dart';

class AvatarWidget extends StatefulWidget {
  final String address;

  AvatarWidget({Key key, @required this.address}) : super(key: key);

  @override
  _AvatarWidgetState createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  File avatarFile;
  String lastAddress;

  @override
  void initState() {
    super.initState();
    this.lastAddress = widget.address;
    _getAvatar();
  }

  Future<void> _getAvatar() async {
    if (widget.address != null) {
      File avatarF = await sl
          .get<UIUtil>()
          .downloadOrRetrieveAvatar(context, widget.address);
      if (await FileUtil().pngHasValidSignature(avatarF)) {
        if (mounted) {
          setState(() {
            avatarFile = avatarF;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.address != lastAddress) {
      setState(() {
        this.lastAddress = widget.address;
        this.avatarFile = null;
      });
      _getAvatar();
    }
    return RepaintBoundary(
      child: avatarFile == null
          ? FlareActor('assets/placeholder_animation.flr',
              animation: 'main', fit: BoxFit.contain)
          : Image.file(avatarFile),
    );
  }
}
