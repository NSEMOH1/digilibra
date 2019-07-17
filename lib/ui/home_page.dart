import 'dart:async';
import 'package:flare_flutter/flare.dart';
import 'package:flare_dart/math/mat2d.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:logging/logging.dart';
import 'package:wallet/ui/widgets/auto_resize_text.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/themes.dart';
import 'package:wallet/dimens.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/model/db/contact.dart';
import 'package:wallet/model/db/appdb.dart';
import 'package:wallet/styles.dart';
import 'package:wallet/app_icons.dart';
import 'package:wallet/ui/contacts/add_contact.dart';
import 'package:wallet/ui/send/send_sheet.dart';
import 'package:wallet/ui/receive/receive_sheet.dart';
import 'package:wallet/ui/settings/settings_drawer.dart';
import 'package:wallet/ui/widgets/buttons.dart';
import 'package:wallet/ui/widgets/app_drawer.dart';
import 'package:wallet/ui/widgets/app_scaffold.dart';
import 'package:wallet/ui/widgets/sheets.dart';
import 'package:wallet/ui/util/routes.dart';
import 'package:wallet/ui/widgets/reactive_refresh.dart';
import 'package:wallet/ui/util/ui_util.dart';
import 'package:wallet/util/sharedprefsutil.dart';
import 'package:wallet/util/fileutil.dart';
import 'package:wallet/util/hapticutil.dart';
import 'package:wallet/util/caseconverter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wallet/bus/events.dart';
import 'package:wallet/model/list_model.dart';
import 'package:wallet/network/model/response/transaction_response_item.dart';
import 'package:wallet/ui/widgets/list_slidable.dart';
import 'package:wallet/constants.dart';
import 'package:wallet/ui/send/send_complete_sheet.dart';

class AppHomePage extends StatefulWidget {
  @override
  _AppHomePageState createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage>
    with
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin,
        FlareController {
  final GlobalKey<AppScaffoldState> _scaffoldKey =
      new GlobalKey<AppScaffoldState>();
  final Logger log = Logger('HomePage');

  // Controller for placeholder card animations
  AnimationController _placeholderCardAnimationController;
  Animation<double> _opacityAnimation;
  bool _animationDisposed;

  // Receive card instance
  AppReceiveSheet receive;

  // A separate unfortunate instance of this list, is a little unfortunate
  // but seems the only way to handle the animations
  final Map<String, GlobalKey<AnimatedListState>> _listKeyMap = Map();
  final Map<String, ListModel<TransactionResponseItem>> _historyListMap = Map();

  // avatar widget
  Widget _avatar;
  Widget _largeAvatar;
  bool _avatarOverlayOpen = false;
  bool _avatarDownloadTriggered = false;
  // List of contacts (Store it so we only have to query the DB once for transaction cards)
  List<Contact> _contacts = List();

  // Price conversion state (BTC, NONE)
  PriceConversion _priceConversion;
  bool _pricesHidden = false;
  bool _isRefreshing = false;
  bool _lockDisabled = false; // whether we should avoid locking the app

  // Animation for swiping to send
  ActorAnimation _sendSlideAnimation;
  ActorAnimation _sendSlideReleaseAnimation;
  double _fanimationPosition;
  bool releaseAnimation = false;

  void initialize(FlutterActorArtboard actor) {
    _fanimationPosition = 0.0;
    _sendSlideAnimation = actor.getAnimation('pull');
    _sendSlideReleaseAnimation = actor.getAnimation('release');
  }

  void setViewTransform(Mat2D viewTransform) {}

  bool advance(FlutterActorArtboard artboard, double elapsed) {
    if (releaseAnimation) {
      _sendSlideReleaseAnimation.apply(
          _sendSlideReleaseAnimation.duration * (1 - _fanimationPosition),
          artboard,
          1.0);
    } else {
      _sendSlideAnimation.apply(
          _sendSlideAnimation.duration * _fanimationPosition, artboard, 1.0);
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _registerBus();
    WidgetsBinding.instance.addObserver(this);
    sl.get<SharedPrefsUtil>().getPriceConversion().then((result) {
      _priceConversion = result;
    });
    _addSampleContact();
    _updateContacts();
    _avatarDownloadTriggered = false;
    // Setup placeholder animation and start
    _animationDisposed = false;
    _placeholderCardAnimationController = new AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _placeholderCardAnimationController
        .addListener(_animationControllerListener);
    _opacityAnimation = new Tween(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(
        parent: _placeholderCardAnimationController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );
    _opacityAnimation.addStatusListener(_animationStatusListener);
    _placeholderCardAnimationController.forward();
  }

  void _animationStatusListener(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
        _placeholderCardAnimationController.forward();
        break;
      case AnimationStatus.completed:
        _placeholderCardAnimationController.reverse();
        break;
      default:
        return null;
    }
  }

  void _animationControllerListener() {
    setState(() {});
  }

  void _startAnimation() {
    if (_animationDisposed) {
      _animationDisposed = false;
      _placeholderCardAnimationController
          .addListener(_animationControllerListener);
      _opacityAnimation.addStatusListener(_animationStatusListener);
      _placeholderCardAnimationController.forward();
    }
  }

  void _disposeAnimation() {
    if (!_animationDisposed) {
      _animationDisposed = true;
      _opacityAnimation.removeStatusListener(_animationStatusListener);
      _placeholderCardAnimationController
          .removeListener(_animationControllerListener);
      _placeholderCardAnimationController.stop();
    }
  }

  /// Add donations contact if it hasnt already been added
  Future<void> _addSampleContact() async {
    bool contactAdded = await sl.get<SharedPrefsUtil>().getFirstContactAdded();
    String address =
        '64735493b84fde794b2af19029753377cf3f42ed2ce0ce81ce4f8f2a22a88351';
    String name = '@Donations';
    if (!contactAdded) {
      bool addressExists =
          await sl.get<DBHelper>().contactExistsWithAddress(address);
      if (addressExists) {
        return;
      }
      bool nameExists = await sl.get<DBHelper>().contactExistsWithName(name);
      if (nameExists) {
        return;
      }
      await sl.get<SharedPrefsUtil>().setFirstContactAdded(true);
      await sl
          .get<DBHelper>()
          .saveContact(Contact(name: name, address: address));
    }
  }

  void _updateContacts() {
    sl.get<DBHelper>().getContacts().then((contacts) {
      setState(() {
        _contacts = contacts;
      });
    });
  }

  StreamSubscription<HistoryHomeEvent> _historySub;
  StreamSubscription<ContactModifiedEvent> _contactModifiedSub;
  StreamSubscription<SendCompleteEvent> _sendCompleteSub;
  StreamSubscription<DisableLockTimeoutEvent> _disableLockSub;
  StreamSubscription<AvatarOverlayClosedEvent> _avatarOverlaySub;
  StreamSubscription<AccountChangedEvent> _switchAccountSub;

  void _registerBus() {
    _historySub = EventTaxiImpl.singleton()
        .registerTo<HistoryHomeEvent>()
        .listen((event) {
      diffAndUpdateHistoryList(event.items);
      setState(() {
        _isRefreshing = false;
      });
    });

    _sendCompleteSub = EventTaxiImpl.singleton()
        .registerTo<SendCompleteEvent>()
        .listen((event) {
      // Route to send complete if received process response for send block
      if (event.to != null) {
        // Route to send complete
        sl.get<DBHelper>().getContactWithAddress(event.to).then((contact) {
          String contactName = contact == null ? null : contact.name;
          Navigator.of(context).popUntil(RouteUtils.withNameLike('/home'));
          AppSendCompleteSheet(event.amount, event.from, contactName)
              .mainBottomSheet(context);
        });
      }
    });
    _contactModifiedSub = EventTaxiImpl.singleton()
        .registerTo<ContactModifiedEvent>()
        .listen((event) {
      _updateContacts();
    });
    _avatarOverlaySub = EventTaxiImpl.singleton()
        .registerTo<AvatarOverlayClosedEvent>()
        .listen((event) {
      Future.delayed(Duration(milliseconds: 150), () {
        setState(() {
          _avatarOverlayOpen = false;
        });
      });
    });
    // Hackish event to block auto-lock functionality
    _disableLockSub = EventTaxiImpl.singleton()
        .registerTo<DisableLockTimeoutEvent>()
        .listen((event) {
      if (event.disable) {
        cancelLockEvent();
      }
      _lockDisabled = event.disable;
    });
    // User changed account
    _switchAccountSub = EventTaxiImpl.singleton()
        .registerTo<AccountChangedEvent>()
        .listen((event) {
      setState(() {
        _avatar = null;
        _largeAvatar = null;
        StateContainer.of(context).wallet.loading = true;
        StateContainer.of(context).wallet.historyLoading = true;
        _startAnimation();
        StateContainer.of(context).updateWallet(account: event.account);
      });
      sl
          .get<UIUtil>()
          .downloadOrRetrieveAvatar(context, event.account.address)
          .then((result) {
        if (result != null) {
          sl.get<FileUtil>().pngHasValidSignature(result).then((valid) {
            if (valid) {
              setState(() {
                _avatar = Image.file(result);
                _largeAvatar = Image.file(result);
              });
            }
          });
        }
      });
      paintQrCode(address: event.account.address);
      if (event.delayPop) {
        Future.delayed(Duration(milliseconds: 300), () {
          Navigator.of(context).popUntil(RouteUtils.withNameLike('/home'));
        });
      } else if (!event.noPop) {
        Navigator.of(context).popUntil(RouteUtils.withNameLike('/home'));
      }
    });
  }

  @override
  void dispose() {
    _destroyBus();
    WidgetsBinding.instance.removeObserver(this);
    _placeholderCardAnimationController.dispose();
    super.dispose();
  }

  void _destroyBus() {
    if (_historySub != null) {
      _historySub.cancel();
    }
    if (_contactModifiedSub != null) {
      _contactModifiedSub.cancel();
    }
    if (_sendCompleteSub != null) {
      _sendCompleteSub.cancel();
    }
    if (_disableLockSub != null) {
      _disableLockSub.cancel();
    }
    if (_avatarOverlaySub != null) {
      _avatarOverlaySub.cancel();
    }
    if (_switchAccountSub != null) {
      _switchAccountSub.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle websocket connection when app is in background
    // terminate it to be eco-friendly
    switch (state) {
      case AppLifecycleState.paused:
        setAppLockEvent();
        super.didChangeAppLifecycleState(state);
        break;
      case AppLifecycleState.resumed:
        cancelLockEvent();
        super.didChangeAppLifecycleState(state);
        break;
      default:
        super.didChangeAppLifecycleState(state);
        break;
    }
  }

  // To lock and unlock the app
  StreamSubscription<dynamic> lockStreamListener;

  Future<void> setAppLockEvent() async {
    if (await sl.get<SharedPrefsUtil>().getLock() && !_lockDisabled) {
      if (lockStreamListener != null) {
        lockStreamListener.cancel();
      }
      Future<dynamic> delayed = new Future.delayed(
          (await sl.get<SharedPrefsUtil>().getLockTimeout()).getDuration());
      delayed.then((_) {
        return true;
      });
      lockStreamListener = delayed.asStream().listen((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
    }
  }

  Future<void> cancelLockEvent() async {
    if (lockStreamListener != null) {
      lockStreamListener.cancel();
    }
  }

  // Used to build list items that haven't been removed.
  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    TransactionResponseItem item =
        _historyListMap[StateContainer.of(context).wallet.address][index];
    String displayName =
        smallScreen(context) ? item.getShorterString() : item.getShortString();
    _contacts.forEach((contact) {
      if (contact.address == item.from) {
        displayName = contact.name;
      }
    });
    return _buildTransactionCard(item, animation, displayName, context);
  }

  // Return widget for list
  Widget _getListWidget(BuildContext context) {
    if (StateContainer.of(context).wallet == null ||
        StateContainer.of(context).wallet.historyLoading) {
      // Loading Animation
      var sentCard = _buildLoadingTransactionCard(
          'Sent', '10244000', '123456789121234', context);
      var receivedCard = _buildLoadingTransactionCard(
          'Sent', 'Received', '123456789121234', context);
      return ReactiveRefreshIndicator(
          backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
          onRefresh: _refresh,
          isRefreshing: _isRefreshing,
          child: ListView(
            padding: EdgeInsetsDirectional.fromSTEB(0, 5.0, 0, 15.0),
            children: <Widget>[
              sentCard,
              receivedCard,
              sentCard,
              sentCard,
              receivedCard,
              sentCard,
              receivedCard,
              sentCard,
            ],
          ));
    } else if (StateContainer.of(context).wallet.history.length == 0) {
      _disposeAnimation();
      return ReactiveRefreshIndicator(
        backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(0, 5.0, 0, 15.0),
          children: <Widget>[
            _buildWelcomeTransactionCard(context),
            _buildDummyTransactionCard(
                AppLocalization.of(context).sent,
                AppLocalization.of(context).exampleCardLittle,
                AppLocalization.of(context).exampleCardTo,
                context),
            _buildDummyTransactionCard(
                AppLocalization.of(context).received,
                AppLocalization.of(context).exampleCardLot,
                AppLocalization.of(context).exampleCardFrom,
                context),
          ],
        ),
        onRefresh: _refresh,
        isRefreshing: _isRefreshing,
      );
    } else {
      _disposeAnimation();
    }
    // Setup history list
    if (!_listKeyMap.containsKey(StateContainer.of(context).wallet.address)) {
      _listKeyMap.putIfAbsent(StateContainer.of(context).wallet.address,
          () => GlobalKey<AnimatedListState>());
      setState(() {
        _historyListMap.putIfAbsent(
            StateContainer.of(context).wallet.address,
            () => ListModel<TransactionResponseItem>(
                  listKey:
                      _listKeyMap[StateContainer.of(context).wallet.address],
                  initialItems: StateContainer.of(context).wallet.history,
                ));
      });
    }
    return ReactiveRefreshIndicator(
      backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
      child: AnimatedList(
        key: _listKeyMap[StateContainer.of(context).wallet.address],
        padding: EdgeInsetsDirectional.fromSTEB(0, 5.0, 0, 15.0),
        initialItemCount:
            _historyListMap[StateContainer.of(context).wallet.address].length,
        itemBuilder: _buildItem,
      ),
      onRefresh: _refresh,
      isRefreshing: _isRefreshing,
    );
  }

  // Refresh list
  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
    });
    sl.get<HapticUtil>().success();
    // Hide refresh indicator after 3 seconds if no server response
    Future.delayed(new Duration(seconds: 3), () {
      setState(() {
        _isRefreshing = false;
      });
    });
  }

  void diffAndUpdateHistoryList(List<TransactionResponseItem> newList) {
    if (newList == null ||
        newList.length == 0 ||
        _historyListMap[StateContainer.of(context).wallet.address] == null)
      return;
    /*
    newList
        .where((item) => !_historyListMap[StateContainer.of(context).wallet.address].items.contains(item))
        .forEach((historyItem) {
      setState(() {
        _historyListMap[StateContainer.of(context).wallet.address].insertAtTop(historyItem);
      });
    });
    */
    setState(() {
      _historyListMap.update(
          StateContainer.of(context).wallet.address,
          (data) => data = ListModel<TransactionResponseItem>(
                listKey: _listKeyMap[StateContainer.of(context).wallet.address],
                initialItems: StateContainer.of(context).wallet.history,
              ));
    });
  }

  void paintQrCode({String address}) {
    QrPainter painter = QrPainter(
      data:
          address == null ? StateContainer.of(context).wallet.address : address,
      version: 6,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );
    painter.toImageData(MediaQuery.of(context).size.width).then((byteData) {
      setState(() {
        receive = AppReceiveSheet(
          Container(
              width: MediaQuery.of(context).size.width / 2.675,
              child: Image.memory(byteData.buffer.asUint8List())),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Create QR ahead of time because it improves performance this way
    if (receive == null && StateContainer.of(context).wallet != null) {
      paintQrCode();
    }

    // Download/Retrieve avatar
    if (!_avatarDownloadTriggered &&
        StateContainer.of(context).wallet != null) {
      _avatarDownloadTriggered = true;

      sl
          .get<UIUtil>()
          .downloadOrRetrieveAvatar(
              context, StateContainer.of(context).wallet.address)
          .then((result) {
        if (result != null) {
          sl.get<FileUtil>().pngHasValidSignature(result).then((valid) {
            if (valid) {
              setState(() {
                _avatar = Image.file(result);
              });
            }
          });
        }
      });
    }
    return AppScaffold(
      resizeToAvoidBottomPadding: false,
      key: _scaffoldKey,
      backgroundColor: StateContainer.of(context).curTheme.background,
      drawer: SizedBox(
        width: sl.get<UIUtil>().drawerWidth(context),
        child: AppDrawer(
          child: SettingsSheet(),
        ),
      ),
      body: SafeArea(
        minimum: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.045,
            bottom: MediaQuery.of(context).size.height * 0.035),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            //Main Card
            _buildMainCard(context, _scaffoldKey),
            //Main Card End
            //Transactions Text
            Container(
              margin: EdgeInsetsDirectional.fromSTEB(30.0, 20.0, 26.0, 0.0),
              child: Row(
                children: <Widget>[
                  Text(
                    CaseChange.toUpperCase(
                        AppLocalization.of(context).transactions, context),
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w100,
                      color: StateContainer.of(context).curTheme.text,
                    ),
                  ),
                ],
              ),
            ), //Transactions Text End

            //Transactions List
            Expanded(
              child: Stack(
                children: <Widget>[
                  _getListWidget(context),
                  //List Top Gradient End
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 10.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            StateContainer.of(context).curTheme.background00,
                            StateContainer.of(context).curTheme.background
                          ],
                          begin: AlignmentDirectional(0.5, 1.0),
                          end: AlignmentDirectional(0.5, -1.0),
                        ),
                      ),
                    ),
                  ), // List Top Gradient End

                  //List Bottom Gradient
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 30.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            StateContainer.of(context).curTheme.background00,
                            StateContainer.of(context).curTheme.background
                          ],
                          begin: AlignmentDirectional(0.5, -1),
                          end: AlignmentDirectional(0.5, 0.5),
                        ),
                      ),
                    ),
                  ), //List Bottom Gradient End
                ],
              ),
            ), //Transactions List End

            //Buttons Area
            Container(
              color: StateContainer.of(context).curTheme.background,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          StateContainer.of(context).curTheme.boxShadowButton
                        ],
                      ),
                      height: 55,
                      margin: EdgeInsetsDirectional.only(
                          start: 14, top: 0.0, end: 7.0),
                      child: FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100.0)),
                        color: receive != null
                            ? StateContainer.of(context).curTheme.primary
                            : StateContainer.of(context).curTheme.primary60,
                        child: AutoSizeText(
                          AppLocalization.of(context).receive,
                          textAlign: TextAlign.center,
                          style: AppStyles.textStyleButtonPrimary(context),
                          maxLines: 1,
                          stepGranularity: 0.5,
                        ),
                        onPressed: () {
                          if (receive == null) {
                            return;
                          }
                          receive.mainBottomSheet(context);
                        },
                        highlightColor: receive != null
                            ? StateContainer.of(context).curTheme.background40
                            : Colors.transparent,
                        splashColor: receive != null
                            ? StateContainer.of(context).curTheme.background40
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          StateContainer.of(context).curTheme.boxShadowButton
                        ],
                      ),
                      height: 55,
                      margin: EdgeInsetsDirectional.only(
                          start: 7, top: 0.0, end: 14.0),
                      child: FlatButton(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100.0)),
                        color: StateContainer.of(context).wallet != null &&
                                StateContainer.of(context)
                                        .wallet
                                        .accountBalance >
                                    BigInt.zero
                            ? StateContainer.of(context).curTheme.primary
                            : StateContainer.of(context).curTheme.primary60,
                        child: AutoSizeText(
                          AppLocalization.of(context).send,
                          textAlign: TextAlign.center,
                          style: AppStyles.textStyleButtonPrimary(context),
                          maxLines: 1,
                          stepGranularity: 0.5,
                        ),
                        onPressed: () {
                          if (StateContainer.of(context).wallet != null &&
                              StateContainer.of(context).wallet.accountBalance >
                                  BigInt.zero) {
                            AppSendSheet().mainBottomSheet(context);
                          }
                        },
                        highlightColor: StateContainer.of(context).wallet !=
                                    null &&
                                StateContainer.of(context)
                                        .wallet
                                        .accountBalance >
                                    BigInt.zero
                            ? StateContainer.of(context).curTheme.background40
                            : Colors.transparent,
                        splashColor: StateContainer.of(context).wallet !=
                                    null &&
                                StateContainer.of(context)
                                        .wallet
                                        .accountBalance >
                                    BigInt.zero
                            ? StateContainer.of(context).curTheme.background40
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ), //Buttons Area End
          ],
        ),
      ),
    );
  }

  // Transaction Card/List Item
  Widget _buildTransactionCard(TransactionResponseItem item,
      Animation<double> animation, String displayName, BuildContext context) {
    TransactionDetailsSheet transactionDetails =
        TransactionDetailsSheet(item.version, item.from, displayName);
    String text;
    IconData icon;
    Color iconColor;
    if (item.from != MintAccount) {
      text = AppLocalization.of(context).sent;
      icon = AppIcons.sent;
      iconColor = StateContainer.of(context).curTheme.text60;
    } else {
      text = AppLocalization.of(context).received;
      icon = AppIcons.received;
      iconColor = StateContainer.of(context).curTheme.primary60;
    }
    return Slidable(
      delegate: SlidableScrollDelegate(),
      actionExtentRatio: 0.35,
      movementDuration: Duration(milliseconds: 300),
      enabled: StateContainer.of(context).wallet != null &&
          StateContainer.of(context).wallet.accountBalance > BigInt.zero,
      onTriggered: (preempt) {
        if (preempt) {
          setState(() {
            releaseAnimation = true;
          });
        } else {
          // See if a contact
          sl.get<DBHelper>().getContactWithAddress(item.from).then((contact) {
            // Go to send with address
            AppSendSheet(
                    contact: contact,
                    address: item.from,
                    quickSendAmount: item.value)
                .mainBottomSheet(context);
          });
        }
      },
      onAnimationChanged: (animation) {
        if (animation != null) {
          _fanimationPosition = animation.value;
          if (animation.value == 0.0 && releaseAnimation) {
            setState(() {
              releaseAnimation = false;
            });
          }
        }
      },
      secondaryActions: <Widget>[
        SlideAction(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            margin: EdgeInsetsDirectional.only(
                end: MediaQuery.of(context).size.width * 0.15,
                top: 4,
                bottom: 4),
            child: Container(
              alignment: AlignmentDirectional(-0.5, 0),
              constraints: BoxConstraints.expand(),
              child: FlareActor('assets/pulltosend_animation.flr',
                  animation: 'pull',
                  fit: BoxFit.contain,
                  controller: this,
                  color: StateContainer.of(context).curTheme.primary),
            ),
          ),
        ),
      ],
      child: _SizeTransitionNoClip(
        sizeFactor: animation,
        child: Container(
          margin: EdgeInsetsDirectional.fromSTEB(14.0, 4.0, 14.0, 4.0),
          decoration: BoxDecoration(
            color: StateContainer.of(context).curTheme.backgroundDark,
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: [StateContainer.of(context).curTheme.boxShadow],
          ),
          child: FlatButton(
            highlightColor: StateContainer.of(context).curTheme.text15,
            splashColor: StateContainer.of(context).curTheme.text15,
            color: StateContainer.of(context).curTheme.backgroundDark,
            padding: EdgeInsets.all(0.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
            onPressed: () => transactionDetails.mainBottomSheet(context),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 14.0, horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                            margin: EdgeInsetsDirectional.only(end: 16.0),
                            child: Icon(icon, color: iconColor, size: 20)),
                        Container(
                          width: MediaQuery.of(context).size.width / 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                text,
                                textAlign: TextAlign.start,
                                style:
                                    AppStyles.textStyleTransactionType(context),
                              ),
                              RichText(
                                textAlign: TextAlign.start,
                                text: TextSpan(
                                  text: '',
                                  children: [
                                    TextSpan(
                                      text: item.getFormattedAmount(),
                                      style:
                                          AppStyles.textStyleTransactionAmount(
                                              context),
                                    ),
                                    TextSpan(
                                      text: ' LIBRA',
                                      style: AppStyles.textStyleTransactionUnit(
                                          context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width / 2.4,
                      child: Text(
                        displayName,
                        textAlign: TextAlign.end,
                        style: AppStyles.textStyleTransactionAddress(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  } //Transaction Card End

  // Dummy Transaction Card
  Widget _buildDummyTransactionCard(
      String type, String amount, String address, BuildContext context) {
    String text;
    IconData icon;
    Color iconColor;
    if (type == AppLocalization.of(context).sent) {
      text = AppLocalization.of(context).sent;
      icon = AppIcons.sent;
      iconColor = StateContainer.of(context).curTheme.text60;
    } else {
      text = AppLocalization.of(context).received;
      icon = AppIcons.received;
      iconColor = StateContainer.of(context).curTheme.primary60;
    }
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(14.0, 4.0, 14.0, 4.0),
      decoration: BoxDecoration(
        color: StateContainer.of(context).curTheme.backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer.of(context).curTheme.boxShadow],
      ),
      child: FlatButton(
        onPressed: () {
          return null;
        },
        highlightColor: StateContainer.of(context).curTheme.text15,
        splashColor: StateContainer.of(context).curTheme.text15,
        color: StateContainer.of(context).curTheme.backgroundDark,
        padding: EdgeInsets.all(0.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                        margin: EdgeInsetsDirectional.only(end: 16.0),
                        child: Icon(icon, color: iconColor, size: 20)),
                    Container(
                      width: MediaQuery.of(context).size.width / 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            text,
                            textAlign: TextAlign.start,
                            style: AppStyles.textStyleTransactionType(context),
                          ),
                          RichText(
                            textAlign: TextAlign.start,
                            text: TextSpan(
                              text: '',
                              children: [
                                TextSpan(
                                  text: amount,
                                  style: AppStyles.textStyleTransactionAmount(
                                      context),
                                ),
                                TextSpan(
                                  text: ' LIBRA',
                                  style: AppStyles.textStyleTransactionUnit(
                                      context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  width: MediaQuery.of(context).size.width / 2.4,
                  child: Text(
                    address,
                    textAlign: TextAlign.end,
                    style: AppStyles.textStyleTransactionAddress(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } //Dummy Transaction Card End

  // Welcome Card
  TextSpan _getExampleHeaderSpan(BuildContext context) {
    String workingStr;
    if (StateContainer.of(context).selectedAccount == null ||
        StateContainer.of(context).selectedAccount.index == 0) {
      workingStr = AppLocalization.of(context).exampleCardIntro;
    } else {
      workingStr = AppLocalization.of(context).newAccountIntro;
    }
    if (!workingStr.contains('LIBRA')) {
      return TextSpan(
        text: workingStr,
        style: AppStyles.textStyleTransactionWelcome(context),
      );
    }
    // Colorize LIBRA
    List<String> splitStr = workingStr.split('LIBRA');
    if (splitStr.length != 2) {
      return TextSpan(
        text: workingStr,
        style: AppStyles.textStyleTransactionWelcome(context),
      );
    }
    return TextSpan(
      text: '',
      children: [
        TextSpan(
          text: splitStr[0],
          style: AppStyles.textStyleTransactionWelcome(context),
        ),
        TextSpan(
          text: 'LIBRA',
          style: AppStyles.textStyleTransactionWelcomePrimary(context),
        ),
        TextSpan(
          text: splitStr[1],
          style: AppStyles.textStyleTransactionWelcome(context),
        ),
      ],
    );
  }

  Widget _buildWelcomeTransactionCard(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(14.0, 4.0, 14.0, 4.0),
      decoration: BoxDecoration(
        color: StateContainer.of(context).curTheme.backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer.of(context).curTheme.boxShadow],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              width: 7.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.0),
                    bottomLeft: Radius.circular(10.0)),
                color: StateContainer.of(context).curTheme.primary,
                boxShadow: [StateContainer.of(context).curTheme.boxShadow],
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 14.0, horizontal: 15.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: _getExampleHeaderSpan(context),
                ),
              ),
            ),
            Container(
              width: 7.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topRight: Radius.circular(10.0),
                    bottomRight: Radius.circular(10.0)),
                color: StateContainer.of(context).curTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  } // Welcome Card End

  // Loading Transaction Card
  Widget _buildLoadingTransactionCard(
      String type, String amount, String address, BuildContext context) {
    String text;
    Color iconColor;
    IconData icon = AppIcons.dotfilled;
    if (type == 'Sent') {
      text = 'Sent';
      iconColor = StateContainer.of(context).curTheme.text20;
    } else {
      text = 'Received';
      iconColor = StateContainer.of(context).curTheme.primary20;
    }
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(14.0, 4.0, 14.0, 4.0),
      decoration: BoxDecoration(
        color: StateContainer.of(context).curTheme.backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer.of(context).curTheme.boxShadow],
      ),
      child: FlatButton(
        onPressed: () {
          return null;
        },
        highlightColor: StateContainer.of(context).curTheme.text15,
        splashColor: StateContainer.of(context).curTheme.text15,
        color: StateContainer.of(context).curTheme.backgroundDark,
        padding: EdgeInsets.all(0.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // Transaction Icon
                    Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                          margin: EdgeInsetsDirectional.only(end: 16.0),
                          child: Icon(icon, color: iconColor, size: 20)),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width / 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Transaction Type Text
                          Container(
                            child: Stack(
                              alignment: AlignmentDirectional(-1, 0),
                              children: <Widget>[
                                Text(
                                  text,
                                  textAlign: TextAlign.start,
                                  style: AppStyles.textStyleCurrencyAltHidden(),
                                ),
                                Opacity(
                                  opacity: _opacityAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: StateContainer.of(context)
                                          .curTheme
                                          .text45,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      text,
                                      textAlign: TextAlign.start,
                                      style:
                                          AppStyles.textStyleCurrencyAltHidden(
                                              fontSize: AppFontSizes.small - 4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Amount Text
                          Container(
                            child: Stack(
                              alignment: AlignmentDirectional(-1, 0),
                              children: <Widget>[
                                Text(amount,
                                    textAlign: TextAlign.start,
                                    style: AppStyles.textStyleCurrencyAltHidden(
                                        fontSize: AppFontSizes.smallest)),
                                Opacity(
                                  opacity: _opacityAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: StateContainer.of(context)
                                          .curTheme
                                          .primary20,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(amount,
                                        textAlign: TextAlign.start,
                                        style: AppStyles
                                            .textStyleCurrencyAltHidden(
                                                fontSize:
                                                    AppFontSizes.smallest - 3)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Address Text
                Container(
                  width: MediaQuery.of(context).size.width / 2.4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        child: Stack(
                          alignment: AlignmentDirectional(1, 0),
                          children: <Widget>[
                            Text(address,
                                textAlign: TextAlign.end,
                                style: AppStyles.textStyleAddressHidden(
                                    fontSize: AppFontSizes.smallest)),
                            Opacity(
                              opacity: _opacityAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: StateContainer.of(context)
                                      .curTheme
                                      .text20,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(address,
                                    textAlign: TextAlign.end,
                                    style: AppStyles.textStyleAddressHidden(
                                        fontSize: AppFontSizes.smallest - 3)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } // Loading Transaction Card End

  //Main Card
  Widget _buildMainCard(BuildContext context, _scaffoldKey) {
    return Container(
      decoration: BoxDecoration(
        color: StateContainer.of(context).curTheme.backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer.of(context).curTheme.boxShadow],
      ),
      margin: EdgeInsets.only(
          left: 14.0,
          right: 14.0,
          top: MediaQuery.of(context).size.height * 0.005),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            width: 90.0,
            height: 120,
            alignment: AlignmentDirectional(-1, -1),
            child: Container(
              margin: EdgeInsetsDirectional.only(top: 5, start: 5),
              height: 50,
              width: 50,
              child: FlatButton(
                  highlightColor: StateContainer.of(context).curTheme.text15,
                  splashColor: StateContainer.of(context).curTheme.text15,
                  onPressed: () {
                    _scaffoldKey.currentState.openDrawer();
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0)),
                  padding: EdgeInsets.all(0.0),
                  child: Icon(AppIcons.settings,
                      color: StateContainer.of(context).curTheme.text,
                      size: 24)),
            ),
          ),
          _getBalanceWidget(context),
          Container(
            width: 90.0,
            height: 90.0,
            child: _avatar == null
                ? _avatar = FlareActor('assets/placeholder_animation.flr',
                    animation: 'main', fit: BoxFit.contain)
                : FlatButton(
                    highlightColor: StateContainer.of(context).curTheme.text15,
                    splashColor: StateContainer.of(context).curTheme.text15,
                    child: _avatarOverlayOpen
                        ? SizedBox()
                        : Stack(children: <Widget>[
                            Container(
                                width: 80, height: 80, child: _largeAvatar),
                            Center(
                              child: Container(
                                width: 90,
                                height: 90,
                                color: StateContainer.of(context)
                                    .curTheme
                                    .backgroundDark,
                              ),
                            ),
                            _avatar
                          ]),
                    padding: EdgeInsets.all(0.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100.0)),
                    onPressed: () {
                      if (_avatarOverlayOpen || _largeAvatar == null) {
                        return;
                      }
                      setState(() {
                        _avatarOverlayOpen = true;
                      });
                      Navigator.of(context).push(AvatarOverlay(_largeAvatar));
                    }),
          ),
        ],
      ),
    );
  } //Main Card

  // Get balance display
  Widget _getBalanceWidget(BuildContext context) {
    if (StateContainer.of(context).wallet == null ||
        StateContainer.of(context).wallet.loading) {
      // Placeholder for balance text
      return Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              child: Stack(
                alignment: AlignmentDirectional(0, 0),
                children: <Widget>[
                  Text('1234567',
                      textAlign: TextAlign.center,
                      style: AppStyles.textStyleCurrencyAltHidden(
                          fontSize: AppFontSizes.small)),
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: StateContainer.of(context).curTheme.text20,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('1234567',
                          textAlign: TextAlign.center,
                          style: AppStyles.textStyleCurrencyAltHidden(
                              fontSize: AppFontSizes.small - 3)),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 225),
              child: Stack(
                alignment: AlignmentDirectional(0, 0),
                children: <Widget>[
                  AutoSizeText(
                    '1234567',
                    style: AppStyles.textStyleCurrencyAltHidden(
                        fontSize: AppFontSizes.largestc,
                        fontWeight: FontWeight.w900),
                    maxLines: 1,
                    stepGranularity: 0.1,
                    minFontSize: 1,
                  ),
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: StateContainer.of(context).curTheme.primary60,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: AutoSizeText(
                        '1234567',
                        style: AppStyles.textStyleCurrencyAltHidden(
                            fontSize: AppFontSizes.largestc - 8,
                            fontWeight: FontWeight.w900),
                        maxLines: 1,
                        stepGranularity: 0.1,
                        minFontSize: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              child: Stack(
                alignment: AlignmentDirectional(0, 0),
                children: <Widget>[
                  Text('1234567',
                      textAlign: TextAlign.center,
                      style: AppStyles.textStyleCurrencyAltHidden()),
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: StateContainer.of(context).curTheme.text20,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('1234567',
                          textAlign: TextAlign.center,
                          style: AppStyles.textStyleCurrencyAltHidden(
                              fontSize: AppFontSizes.small - 3)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        if (_priceConversion == PriceConversion.NONE) {
          // Hide prices
          setState(() {
            _pricesHidden = true;
            _priceConversion = PriceConversion.NONE;
          });
          sl.get<SharedPrefsUtil>().setPriceConversion(PriceConversion.NONE);
        } else {
          // Cycle to BTC price
          setState(() {
            _pricesHidden = false;
            _priceConversion = PriceConversion.BTC;
          });
          sl.get<SharedPrefsUtil>().setPriceConversion(PriceConversion.BTC);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
                StateContainer.of(context).wallet.getLocalCurrencyPrice(
                    locale: StateContainer.of(context).currencyLocale),
                textAlign: TextAlign.center,
                style: _pricesHidden
                    ? AppStyles.textStyleCurrencyAltHidden()
                    : AppStyles.textStyleCurrencyAlt(context)),
            Container(
              margin: EdgeInsetsDirectional.only(end: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 225),
                    child: AutoSizeText.rich(
                      TextSpan(
                        children: [
                          // Currency Icon
                          TextSpan(
                            text: '',
                            style: TextStyle(
                              fontFamily: 'AppIcons',
                              color:
                                  StateContainer.of(context).curTheme.primary,
                              fontSize: 23.0,
                            ),
                          ),
                          // Main balance text
                          TextSpan(
                            text: StateContainer.of(context)
                                .wallet
                                .getAccountBalanceDisplay(),
                            style: AppStyles.textStyleCurrency(context),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      style: TextStyle(fontSize: 28.0),
                      stepGranularity: 0.1,
                      minFontSize: 1,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: <Widget>[
                Icon(AppIcons.btc,
                    color: _priceConversion == PriceConversion.NONE
                        ? Colors.transparent
                        : StateContainer.of(context).curTheme.text60,
                    size: 14),
                Text(StateContainer.of(context).wallet.btcPrice,
                    textAlign: TextAlign.center,
                    style: _pricesHidden
                        ? AppStyles.textStyleCurrencyAltHidden()
                        : AppStyles.textStyleCurrencyAlt(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionDetailsSheet {
  String _hash;
  String _address;
  String _displayName;
  TransactionDetailsSheet(String hash, String address, String displayName)
      : _hash = hash,
        _address = address,
        _displayName = displayName;
  // Current state references
  bool _addressCopied = false;
  // Timer reference so we can cancel repeated events
  Timer _addressCopiedTimer;

  mainBottomSheet(BuildContext context) {
    AppSheets.showAppHeightEightSheet(
        animationDurationMs: 175,
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return SafeArea(
              minimum: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.035,
              ),
              child: Container(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        // A stack for Copy Address and Add Contact buttons
                        Stack(
                          children: <Widget>[
                            // A row for Copy Address Button
                            Row(
                              children: <Widget>[
                                AppButton.buildAppButton(
                                    context,
                                    // Share Address Button
                                    _addressCopied
                                        ? AppButtonType.SUCCESS
                                        : AppButtonType.PRIMARY,
                                    _addressCopied
                                        ? AppLocalization.of(context)
                                            .addressCopied
                                        : AppLocalization.of(context)
                                            .copyAddress,
                                    Dimens.BUTTON_TOP_EXCEPTION_DIMENS,
                                    onPressed: () {
                                  Clipboard.setData(
                                      new ClipboardData(text: _address));
                                  setState(() {
                                    // Set copied style
                                    _addressCopied = true;
                                  });
                                  if (_addressCopiedTimer != null) {
                                    _addressCopiedTimer.cancel();
                                  }
                                  _addressCopiedTimer = new Timer(
                                      const Duration(milliseconds: 800), () {
                                    setState(() {
                                      _addressCopied = false;
                                    });
                                  });
                                }),
                              ],
                            ),
                            // A row for Add Contact Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  margin: EdgeInsetsDirectional.only(
                                      top:
                                          Dimens.BUTTON_TOP_EXCEPTION_DIMENS[1],
                                      end: Dimens
                                          .BUTTON_TOP_EXCEPTION_DIMENS[2]),
                                  child: Container(
                                    height: 55,
                                    width: 55,
                                    // Add Contact Button
                                    child: !_displayName.startsWith('@')
                                        ? FlatButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              AddContactSheet(address: _address)
                                                  .mainBottomSheet(context);
                                            },
                                            splashColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        100.0)),
                                            padding: EdgeInsets.symmetric(
                                                vertical: 10.0, horizontal: 10),
                                            child: Icon(AppIcons.addcontact,
                                                size: 35,
                                                color: _addressCopied
                                                    ? StateContainer.of(context)
                                                        .curTheme
                                                        .successDark
                                                    : StateContainer.of(context)
                                                        .curTheme
                                                        .backgroundDark),
                                          )
                                        : SizedBox(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // A row for View Details button
                        Row(
                          children: <Widget>[
                            AppButton.buildAppButton(
                                context,
                                AppButtonType.PRIMARY_OUTLINE,
                                AppLocalization.of(context).viewDetails,
                                Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (BuildContext context) {
                                return sl
                                    .get<UIUtil>()
                                    .showExplorerWebview(context, _hash);
                              }));
                            }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }
}

// avatar Overlay
class AvatarOverlay extends ModalRoute<void> {
  var avatar;
  AvatarOverlay(this.avatar);

  @override
  Duration get transitionDuration => Duration(milliseconds: 200);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color get barrierColor => AppColors.overlay70;

  @override
  String get barrierLabel => null;

  @override
  bool get maintainState => false;

  Future<bool> _onClosed() async {
    EventTaxiImpl.singleton().fire(AvatarOverlayClosedEvent());
    return true;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Setup position transition
    return WillPopScope(
      onWillPop: _onClosed,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(child: _buildOverlayContent(context)),
      ),
    );
  }

  Widget _buildOverlayContent(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(),
      child: Stack(
        children: <Widget>[
          GestureDetector(
            onTap: () {
              _onClosed();
              Navigator.pop(context);
            },
            child: Container(
              color: Colors.transparent,
              child: SizedBox.expand(),
              constraints: BoxConstraints.expand(),
            ),
          ),
          Container(
            alignment: AlignmentDirectional(0, -0.3),
            child: ClipOval(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width,
                child: avatar,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.42, -0.42),
        end: Offset.zero,
      ).animate(animation),
      child: ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// This is used so that the elevation of the container is kept and the
/// drop shadow is not clipped.
///
class _SizeTransitionNoClip extends AnimatedWidget {
  final Widget child;

  const _SizeTransitionNoClip(
      {@required Animation<double> sizeFactor, this.child})
      : super(listenable: sizeFactor);

  @override
  Widget build(BuildContext context) {
    return new Align(
      alignment: const AlignmentDirectional(-1.0, -1.0),
      widthFactor: null,
      heightFactor: (this.listenable as Animation<double>).value,
      child: child,
    );
  }
}
