import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

class LiamSettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({
            :title => WatchUi.loadResource(Rez.Strings.SettingsTitle) as String
        });

        var savedFont = Properties.getValue("TimeFont");
        var selectedFont = savedFont instanceof Number ? savedFont : 0;
        var labels = [
            Rez.Strings.TimeFontBionicSemiBold,
            Rez.Strings.TimeFontRobotoCondensedBold,
            Rez.Strings.TimeFontRobotoCondensedRegular,
            Rez.Strings.TimeFontRobotoCondensedItalic,
            Rez.Strings.TimeFontNotoSansSCMedium,
            Rez.Strings.TimeFontKosugiRegular,
            Rez.Strings.TimeFontNanumGothicExtraBold,
            Rez.Strings.TimeFontPridiSemiBold,
            Rez.Strings.TimeFontNotoNaskhArabicBold,
            Rez.Strings.TimeFontNotoNaskhArabicRegular,
            Rez.Strings.TimeFontNotoSansHebrewBold,
            Rez.Strings.TimeFontNotoSansHebrewRegular,
            Rez.Strings.TimeFontNotoSansArmenianBold,
            Rez.Strings.TimeFontNotoSansArmenianRegular
        ];
        for (var i = 0; i < labels.size(); i++) {
            addFont(labels[i], i, selectedFont);
        }
    }

    private function addFont(label as Lang.ResourceId, font as Number, selectedFont as Number) as Void {
        var subLabel = font == selectedFont
            ? WatchUi.loadResource(Rez.Strings.Selected) as String
            : null;
        addItem(new WatchUi.MenuItem(label, subLabel, font, {}));
    }
}

class LiamSettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var font = item.getId();
        if (font instanceof Number) {
            Properties.setValue("TimeFont", font);
            getApp().onSettingsChanged();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}