import 'package:flutter/material.dart';
import 'package:getx_demo/common/widget/link_anchor/widget_position_model.dart';

///动画通知-用于滚动外的视图动画联动
typedef AnimationNotification = Function(double value);

///位置通知
typedef PositionNotification = Function(int index);

///滚动通知
typedef ScrollNotification = Function(ScrollController controller);

class LinkAnchorController {
  ///默认值
  final int initIndex;

  ///偏移量
  final double offset;

  ///子视图个数
  late int itemCount;

  ///tab控制器
  late TabController? tabController;

  ///子视图起始位置
  List<WidgetPosition> widgetPositions = [];

  ///滚动视图key
  GlobalKey scrollGlobalKey = GlobalKey();

  ///滚动控件大小
  late Size scrollSize;

  ///子视图key
  late List<GlobalKey> globalKeys =
      List.generate(itemCount, (index) => GlobalKey());

  ///滚动控制器
  late ScrollController scrollController =
      scrollController = ScrollController()..addListener(scrollListener);

  ///对应tab的下标
  WidgetPosition? currentToTabIndex;

  ///定位时向下偏移量
  double get toOffset => offset;

  ///滚动锁-防止多次滚动计算
  bool scrollLock = false;

  ///动画回调
  AnimationNotification? animationNotification;

  ///位置回调
  PositionNotification? positionNotification;

  ///滚动通知
  ScrollNotification? scrollNotification;

  LinkAnchorController({
    this.initIndex = 0,
    this.offset = 0,
    this.tabController,
    this.animationNotification,
    this.positionNotification,
    this.scrollNotification,
  });

  ///页面显示后下一帧回调
  void postFrameCallback(_) {
    //获取子控件位置
    _getPosition();
    //设置初始值
    _setInitIndex();
  }

  ///滚动监听
  void scrollListener() {
    //通知外部
    _scrollNotification();
    //计算位置
    if (!scrollLock) {
      //记录上次位置
      WidgetPosition? tempTabIndex = currentToTabIndex;
      //计算对应tab的下标位置
      _getCurrentToTabIndex(scrollController.position.pixels);
      //判断与上次是否同一个视图位置
      if (tempTabIndex != currentToTabIndex) {
        _toPositionNotification(currentToTabIndex!.index);
      }
    }

    //滚动是动画联动
    double displayHeight = (widgetPositions.first.size.height - offset).abs();
    double temp = scrollController.position.pixels.clamp(0, displayHeight) /
        displayHeight;
    _toAnimationNotification(temp);
  }

  ///用于滚动是通知
  void _scrollNotification() {
    scrollNotification?.call(scrollController);
  }

  ///用于动画值变化通知
  void _toAnimationNotification(double value) {
    animationNotification?.call(value);
  }

  ///用于位置变化通知
  void _toPositionNotification(int index) {
    positionNotification?.call(index);
  }

  ///获取-子视图位置
  void _getPosition() {
    //滚动视图
    RenderBox scrollRenderBox =
        scrollGlobalKey.currentContext!.findRenderObject() as RenderBox;
    //滚动视图-大小
    scrollSize = scrollRenderBox.size;
    //滚动视图-相对于原点 控件的位置
    Offset scrollOffset = scrollRenderBox.localToGlobal(Offset.zero);

    widgetPositions.clear();

    int globalKeyLength = globalKeys.length;

    //倒序遍历-为了计算控件距离scroll底部距离
    double tempHeight = 0;
    for (int index = globalKeyLength - 1; index >= 0; index--) {
      RenderBox widgetRenderBox =
          globalKeys[index].currentContext?.findRenderObject() as RenderBox;
      //子控件大小
      Size widgetSize = widgetRenderBox.size;
      //相对于原点-子控件的位置
      Offset widgetOffset = widgetRenderBox.localToGlobal(Offset.zero);
      //子控件-开始与结束坐标
      double begin = widgetOffset.dy - scrollOffset.dy;
      double end = begin + widgetSize.height;

      widgetPositions.insert(
        0,
        WidgetPosition(
          index: index,
          begin: begin,
          end: end,
          size: widgetSize,
          endToScrollEndHeight: tempHeight,
        ),
      );
      tempHeight += widgetSize.height;
    }
  }

  ///设置初始值
  void _setInitIndex() {
    if (initIndex == 0) return;
    jumpToIndex(initIndex);
    _toPositionNotification(initIndex);
  }

  ///获取-对应tab的下标
  void _getCurrentToTabIndex(double pixels) {
    //兼容顶部偏移量
    pixels += toOffset;
    //判断是否还是当前下标位置
    if (currentToTabIndex != null) {
      if (pixels > currentToTabIndex!.begin &&
          pixels < currentToTabIndex!.end) {
        return;
      }
    }
    //判断对应下标
    for (var element in widgetPositions) {
      if (pixels >= element.begin && pixels <= element.end) {
        currentToTabIndex = element;
        break;
      }
    }
  }

  ///跳转制定偏移量
  Future<void> jumpToOffset(
    double offset, {
    bool animated = false,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.linear,
  }) async {
    //滚动锁
    if (scrollLock) return;
    scrollLock = true;
    if (animated) {
      await scrollController.animateTo(
        offset,
        duration: duration,
        curve: curve,
      );
    } else {
      scrollController.jumpTo(offset);
    }
    scrollLock = false;
  }

  ///跳转对应位置
  Future<void> jumpToIndex(
    int index, {
    bool animated = false,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.linear,
  }) async {
    //滚动锁
    if (scrollLock) return;
    scrollLock = true;
    //防止超出下标
    index = index.clamp(0, itemCount - 1);
    WidgetPosition temp = widgetPositions[index];
    //对应位置的视图y坐标 + 向下的偏移量
    double jumpOffset = temp.begin;
    if (temp.begin - toOffset <= 0) {
      //跳转至顶部-超出scroll最上方-重置为scroll最顶部
      jumpOffset = 0;
    } else if (temp.endToScrollEndHeight + temp.size.height <
        scrollSize.height - toOffset) {
      //防止滚动距离过大而回弹
      double toUpOffset =
          scrollSize.height - temp.endToScrollEndHeight - temp.size.height;
      jumpOffset -= toUpOffset;
    } else {
      jumpOffset -= toOffset;
    }
    if (animated) {
      await scrollController.animateTo(
        jumpOffset,
        duration: duration,
        curve: curve,
      );
    } else {
      scrollController.jumpTo(jumpOffset);
    }
    scrollLock = false;
  }
}