import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class LiamApp extends Application.AppBase {

    private var _view as LiamView?;

    function initialize() {
        AppBase.initialize();
        _view = null;
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        _view = new LiamView();
        return [_view as LiamView];
    }

    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [new LiamSettingsMenu(), new LiamSettingsDelegate()];
    }

    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.refreshSettings();
        }
        WatchUi.requestUpdate();
    }
}

function getApp() as LiamApp {
    return Application.getApp() as LiamApp;
}
