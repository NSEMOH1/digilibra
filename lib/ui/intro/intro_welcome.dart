import 'package:flutter/material.dart';
import 'package:flutter_libra_core/flutter_libra_core.dart';
import 'package:wallet/appstate_container.dart';
import 'package:wallet/dimens.dart';
import 'package:wallet/model/vault.dart';
import 'package:wallet/service_locator.dart';
import 'package:wallet/styles.dart';
import 'package:wallet/localization.dart';
import 'package:wallet/ui/widgets/auto_resize_text.dart';
import 'package:wallet/ui/widgets/buttons.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:wallet/util/librautil.dart';

class IntroWelcomePage extends StatefulWidget {
  @override
  _IntroWelcomePageState createState() => _IntroWelcomePageState();
}

class _IntroWelcomePageState extends State<IntroWelcomePage> {
  var _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      key: _scaffoldKey,
      backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
      body: LayoutBuilder(
        builder: (context, constraints) => SafeArea(
          minimum: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.035,
            top: MediaQuery.of(context).size.height * 0.10,
          ),
          child: Column(
            children: <Widget>[
              //A widget that holds welcome animation + paragraph
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    //Container for the animation
                    Container(
                      //Width/Height ratio for the animation is needed because BoxFit is not working as expected
                      width: double.infinity,
                      height: MediaQuery.of(context).size.width * 5 / 8,
                      child: Stack(
                        children: <Widget>[
                          Center(
                            child: FlareActor(
                              'assets/welcome_animation.flr',
                              animation: 'main',
                              fit: BoxFit.contain,
                              color:
                                  StateContainer.of(context).curTheme.primary,
                            ),
                          )
                        ],
                      ),
                    ),
                    //Container for the paragraph
                    Container(
                      margin:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      child: AutoSizeText(
                        AppLocalization.of(context).welcomeText,
                        style: AppStyles.textStyleParagraph(context),
                        maxLines: 4,
                        stepGranularity: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              //A column with 'New Wallet' and 'Import Wallet' buttons
              Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // New Wallet Button
                      AppButton.buildAppButton(
                          context,
                          AppButtonType.PRIMARY,
                          AppLocalization.of(context).newWallet,
                          Dimens.BUTTON_TOP_DIMENS, onPressed: () {
                        sl
                            .get<Vault>()
                            .setSeed(Entropy.generateEntropy())
                            .then((result) {
                          // Update wallet
                          LibraUtil.loginAccount(context, result).then((_) {
                              Navigator.of(context)
                                  .pushNamed('/intro_backup_safety');
                            });
                        });
                      }),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      // Import Wallet Button
                      AppButton.buildAppButton(
                          context,
                          AppButtonType.PRIMARY_OUTLINE,
                          AppLocalization.of(context).importWallet,
                          Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                        Navigator.of(context).pushNamed('/intro_import');
                      }),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
