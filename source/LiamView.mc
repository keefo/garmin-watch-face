import Toybox.ActivityMonitor;
import Toybox.Application.Properties;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class LiamView extends WatchUi.WatchFace {

    private const KNOWN_NEW_MOON = 947182440;
    private const SYNODIC_MONTH_SECONDS = 2551443;
    private const MOON_CENTER_X = 140;
    private const MOON_CENTER_Y = 260;
    private const MOON_RADIUS = 11;
    // Moon colours as [red, green, blue] 0-255; blends are dithered to the 64-colour palette.
    private const MOON_LIT_RGB = [255, 255, 85];
    private const MOON_MARE_RGB = [235, 235, 85];
    // Unlit side: the sky's navy, a little darker than the sky around the moon.
    private const MOON_DARK_RGB = [0, 0, 30];
    // Faint maria as [x, y, radius] in moon radii, x to the right and y down.
    private const MOON_MARIA = [
        [-0.30, -0.35, 0.25],
        [0.20, -0.38, 0.16],
        [0.32, -0.05, 0.18],
        [-0.50, 0.05, 0.26],
        [-0.12, 0.45, 0.15],
        [0.55, 0.20, 0.12]
    ];
    private const INVERTED_BOTTOM = 151;
    private const TIME_MAX_WIDTH = 184;
    private const SUMMARY_MAX_WIDTH = 196;
    // The night sky is pre-rendered by tools/gen_night_sky.py; keep these in sync with it.
    private const SKY_TOP = 239;
    // Deepest mix reached at the bottom, in sixteenth steps (16 = solid navy).
    private const SKY_MAX_LEVEL = 16;
    // 4x4 ordered-dither thresholds, indexed by row and column modulo 4.
    private const SKY_DITHER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
    // Screen area the cached time image covers: the whole white band under the top line, so no
    // font's digits get clipped. The date is drawn after it, on top.
    private const TIME_CACHE_LEFT = 44;
    private const TIME_CACHE_TOP = 61;
    private const TIME_CACHE_WIDTH = 192;
    private const TIME_CACHE_HEIGHT = 90;
    private const TIME_FONT_SIZE = 104;
    private const TIME_CENTER_Y = 115;
    // Share of the font ascent between the digit centre and the text top.
    private const TIME_DIGIT_CENTER = 0.625;
    // Vector font faces built into the Enduro 3, in the order of the TimeFont setting.
    private const TIME_FONT_FACES = [
        "BionicSemiBold",
        "RobotoCondensedBold",
        "RobotoCondensedRegular",
        "RobotoCondensedRegularItalic",
        "NotoSansSCMedium",
        "KosugiRegular",
        "NanumGothicExtraBold",
        "PridiSemiBoldGarmin",
        "NotoNaskhArabicBold",
        "NotoNaskhArabicRegular",
        "NotoSansHebrewBold",
        "NotoSansHebrewRegular",
        "NotoSansArmenianBold",
        "NotoSansArmenianRegular"
    ];

    private var _hudBuffer as BufferedBitmap?;
    private var _heartIcon as BitmapResource?;
    private var _footstepsIcon as BitmapResource?;
    private var _vo2MaxIcon as BitmapResource?;
    private var _bodyIcon as BitmapResource?;
    private var _edgeText as BitmapResource?;
    private var _edgeTextDark as BitmapResource?;
    private var _chargingIcon as BitmapResource?;
    private var _moonHour as Number;
    private var _sunriseId as Complications.Id;
    private var _sunsetId as Complications.Id;
    private var _weatherId as Complications.Id;
    private var _temperatureId as Complications.Id;
    private var _vo2MaxId as Complications.Id;
    private var _dateFont as Graphics.VectorFont?;
    private var _timeFont as Graphics.VectorFont?;
    private var _timeFontSmall as Graphics.VectorFont?;
    private var _telemetryFont as Graphics.VectorFont?;
    private var _headerFont as Graphics.VectorFont?;
    private var _summaryFonts as Array<Graphics.VectorFont>;
    private var _summaryText as String?;
    private var _summaryFont as Graphics.VectorFont?;
    private var _timeCache as BufferedBitmap?;
    private var _timeCacheText as String?;
    private var _monthNames as Array<String>;
    private var _weekdayNames as Array<String>;
    private var _weatherIcons as Array<BitmapResource>;
    private var _lastBodyBattery as Numeric?;
    private var _timeFontsLoaded as Boolean;

    function initialize() {
        WatchFace.initialize();
        _sunriseId = new Complications.Id(Complications.COMPLICATION_TYPE_SUNRISE);
        _sunsetId = new Complications.Id(Complications.COMPLICATION_TYPE_SUNSET);
        _weatherId = new Complications.Id(Complications.COMPLICATION_TYPE_CURRENT_WEATHER);
        _temperatureId = new Complications.Id(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE);
        _vo2MaxId = new Complications.Id(Complications.COMPLICATION_TYPE_VO2MAX_RUN);
        _monthNames = [];
        _weekdayNames = [];
        _weatherIcons = [];
        _lastBodyBattery = null;
        _summaryFonts = [];
        _summaryText = null;
        _summaryFont = null;
        _timeCache = null;
        _timeCacheText = null;
        _moonHour = -1;
        _timeFontsLoaded = false;
    }

    function onLayout(dc as Dc) as Void {
        _heartIcon = WatchUi.loadResource(Rez.Drawables.HeartIcon) as BitmapResource;
        _footstepsIcon = WatchUi.loadResource(Rez.Drawables.FootstepsIcon) as BitmapResource;
        _vo2MaxIcon = WatchUi.loadResource(Rez.Drawables.Vo2MaxIcon) as BitmapResource;
        _bodyIcon = WatchUi.loadResource(Rez.Drawables.BodyIcon) as BitmapResource;
        _edgeText = WatchUi.loadResource(Rez.Drawables.EdgeText) as BitmapResource;
        _edgeTextDark = WatchUi.loadResource(Rez.Drawables.EdgeTextDark) as BitmapResource;
        _chargingIcon = WatchUi.loadResource(Rez.Drawables.ChargingIcon) as BitmapResource;
        _dateFont = Graphics.getVectorFont({
            :face => "NotoSansSCMedium",
            :size => 22
        });
        _telemetryFont = Graphics.getVectorFont({
            :face => "NotoSansSCMedium",
            :size => 16
        });
        _headerFont = Graphics.getVectorFont({
            :face => "NotoSansSCMedium",
            :size => 18
        });
        _summaryFonts = [];
        _summaryText = null;
        _summaryFont = null;
        _timeCache = null;
        _timeCacheText = null;
        var summarySizes = [16, 14, 12];
        for (var i = 0; i < summarySizes.size(); i++) {
            var summaryFont = Graphics.getVectorFont({
                :face => "NotoSansSCMedium",
                :size => summarySizes[i]
            });
            if (summaryFont != null) {
                _summaryFonts.add(summaryFont);
            }
        }
        _monthNames = [
            WatchUi.loadResource(Rez.Strings.Month1) as String,
            WatchUi.loadResource(Rez.Strings.Month2) as String,
            WatchUi.loadResource(Rez.Strings.Month3) as String,
            WatchUi.loadResource(Rez.Strings.Month4) as String,
            WatchUi.loadResource(Rez.Strings.Month5) as String,
            WatchUi.loadResource(Rez.Strings.Month6) as String,
            WatchUi.loadResource(Rez.Strings.Month7) as String,
            WatchUi.loadResource(Rez.Strings.Month8) as String,
            WatchUi.loadResource(Rez.Strings.Month9) as String,
            WatchUi.loadResource(Rez.Strings.Month10) as String,
            WatchUi.loadResource(Rez.Strings.Month11) as String,
            WatchUi.loadResource(Rez.Strings.Month12) as String
        ];
        _weekdayNames = [
            WatchUi.loadResource(Rez.Strings.WeekdaySunday) as String,
            WatchUi.loadResource(Rez.Strings.WeekdayMonday) as String,
            WatchUi.loadResource(Rez.Strings.WeekdayTuesday) as String,
            WatchUi.loadResource(Rez.Strings.WeekdayWednesday) as String,
            WatchUi.loadResource(Rez.Strings.WeekdayThursday) as String,
            WatchUi.loadResource(Rez.Strings.WeekdayFriday) as String,
            WatchUi.loadResource(Rez.Strings.WeekdaySaturday) as String
        ];
        _weatherIcons = [
            WatchUi.loadResource(Rez.Drawables.WeatherClear) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherClearNight) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherCloud) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherFog) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherMixed) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherNightCloudy) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherNightRain) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherPartlyCloudy) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherRain) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherSnow) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherThunderstorm) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherWind) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherHeavyRain) as BitmapResource,
            WatchUi.loadResource(Rez.Drawables.WeatherHeavySnow) as BitmapResource
        ];
        _hudBuffer = Graphics.createBufferedBitmap({
            :width => dc.getWidth(),
            :height => dc.getHeight()
        }).get() as BufferedBitmap;

        drawStaticHud(_hudBuffer.getDc());
        Complications.registerComplicationChangeCallback(method(:onComplicationChange));
        Complications.subscribeToUpdates(_sunriseId);
        Complications.subscribeToUpdates(_sunsetId);
        Complications.subscribeToUpdates(_weatherId);
        Complications.subscribeToUpdates(_temperatureId);
        Complications.subscribeToUpdates(_vo2MaxId);
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        // The moon lives in the static background; repaint its patch of sky when the hour changes.
        var moonHour = Time.now().value() / 3600;
        if (moonHour != _moonHour && _hudBuffer != null) {
            var hudDc = _hudBuffer.getDc();
            var reach = MOON_RADIUS + 1;
            drawNightSky(hudDc, MOON_CENTER_X - reach, MOON_CENTER_Y - reach, MOON_CENTER_X + reach + 1, MOON_CENTER_Y + reach + 1);
            drawMoon(hudDc, MOON_CENTER_X, MOON_CENTER_Y, getMoonPhase(Time.now()));
            _moonHour = moonHour;
        }
        drawBackground(dc);

        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var hourFormat = "%02d";
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
            hourFormat = "%d";
        }
        var timeString = Lang.format("$1$:$2$", [hour.format(hourFormat), clockTime.min.format("%02d")]);
        var dateInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayString = dateInfo.day.format("%d");
        var monthString = _monthNames[(dateInfo.month as Number) - 1];
        var weekdayString = _weekdayNames[(dateInfo.day_of_week as Number) - 1];
        var systemStats = System.getSystemStats();
        var battery = (systemStats.battery + 0.5).toNumber();
        var batteryInDays = systemStats.batteryInDays;
        var charging = systemStats.charging;
        var activityInfo = ActivityMonitor.getInfo();
        var steps = activityInfo.steps;
        var calories = activityInfo.calories;
        var distance = activityInfo.distance;
        var activeMinutesDay = activityInfo.activeMinutesDay;
        var activeMinutes = activeMinutesDay == null ? null : activeMinutesDay.total;
        var heartRate = getLatestSensorValue(:getHeartRateHistory);
        var maxHeartRate = ActivityMonitor.getHeartRateHistory(null, false).getMax();
        var bodyBattery = getBodyBattery();
        var sunrise = getSolarTime(_sunriseId);
        var sunset = getSolarTime(_sunsetId);
        var weather = Complications.getComplication(_weatherId);
        var temperature = Complications.getComplication(_temperatureId).value;
        var vo2MaxValue = Complications.getComplication(_vo2MaxId).value;
        var vo2Max = vo2MaxValue == null ? null : vo2MaxValue as Numeric;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        if (!_timeFontsLoaded) {
            loadTimeFonts(dc);
        }
        var timeFont = _timeFont != null && dc.getTextWidthInPixels(timeString, _timeFont) <= TIME_MAX_WIDTH
            ? _timeFont
            : _timeFontSmall;
        if (timeFont == null) {
            timeFont = Graphics.FONT_NUMBER_MEDIUM;
        }
        if (_timeCache == null || !timeString.equals(_timeCacheText)) {
            renderTimeCache(timeFont, timeString);
        }
        if (_timeCache != null) {
            dc.drawBitmap(TIME_CACHE_LEFT, TIME_CACHE_TOP, _timeCache);
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        drawDate(dc, weekdayString, dayString, monthString);
        drawWeatherIcon(dc, weather.value);
        drawBattery(dc, battery, batteryInDays, charging);
        drawSolarIntensity(dc, systemStats.solarIntensity);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var headerFont = _headerFont == null ? Graphics.FONT_SYSTEM_XTINY : _headerFont;
        dc.drawText(114, 22, headerFont, formatTemperature(temperature), Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(114, 38, headerFont, formatWind(Weather.getCurrentConditions()), Graphics.TEXT_JUSTIFY_RIGHT);
        drawSolarTime(dc, 166, 22, sunrise, true);
        drawSolarTime(dc, 166, 38, sunset, false);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(100, 173, Graphics.FONT_XTINY, formatHeartRate(heartRate, maxHeartRate), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(184, 173, Graphics.FONT_XTINY, formatValue(bodyBattery, "%d"), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(100, 202, Graphics.FONT_XTINY, formatValue(steps, "%d"), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(184, 202, Graphics.FONT_XTINY, formatValue(vo2Max, "%d"), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawSummary(dc,
            "CAL " + formatCalories(calories)
            + "  ·  DIST " + formatDistance(distance)
            + "  ·  INT " + formatValue(activeMinutes, "%d") + "m");
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
    }

    function onEnterSleep() as Void {
    }

    function onComplicationChange(id as Complications.Id) as Void {
        if (id.equals(_sunriseId) || id.equals(_sunsetId) || id.equals(_weatherId) || id.equals(_temperatureId) || id.equals(_vo2MaxId)) {
            WatchUi.requestUpdate();
        }
    }

    function refreshSettings() as Void {
        _timeFontsLoaded = false;
        if (_hudBuffer != null) {
            drawStaticHud(_hudBuffer.getDc());
        }
    }

    private function drawStaticHud(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        drawNightSky(dc, 0, SKY_TOP, dc.getWidth(), dc.getHeight());

        dc.setClip(0, 0, dc.getWidth(), INVERTED_BOTTOM);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(140, 140, 140);
        dc.clearClip();

        dc.setPenWidth(1);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(22, 60, 258, 60);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(28, 222, 252, 222);
        dc.drawLine(140, 160, 140, 215);

        if (_edgeTextDark != null) {
            dc.setClip(0, 0, dc.getWidth(), INVERTED_BOTTOM);
            dc.drawBitmap(-3, 74, _edgeTextDark);
        }
        if (_edgeText != null) {
            dc.setClip(0, INVERTED_BOTTOM, dc.getWidth(), dc.getHeight() - INVERTED_BOTTOM);
            dc.drawBitmap(-3, 74, _edgeText);
        }
        dc.clearClip();

        if (_bodyIcon != null) {
            dc.drawBitmap(153, 161, _bodyIcon);
        }

        if (_vo2MaxIcon != null) {
            dc.drawBitmap(153, 194, _vo2MaxIcon);
        }

        if (_heartIcon != null) {
            dc.drawBitmap(110, 162, _heartIcon);
        }
        if (_footstepsIcon != null) {
            dc.drawBitmap(110, 189, _footstepsIcon);
        }

        // The moon is drawn by the next onUpdate; doing both here exceeds the watchdog limit.
        _moonHour = -1;
    }

    // Pre-rendered night-sky gradient below the summary line, limited to [left, right) x [top, bottom).
    private function drawNightSky(dc as Dc, left as Number, top as Number, right as Number, bottom as Number) as Void {
        var sky = WatchUi.loadResource(Rez.Drawables.NightSky) as BitmapResource;
        dc.setClip(left, top, right - left, bottom - top);
        dc.drawBitmap(0, SKY_TOP, sky);
        dc.clearClip();
    }

    private function skyLevel(y as Number, height as Number) as Number {
        return ((y - SKY_TOP) * SKY_MAX_LEVEL) / height;
    }

    private function drawBackground(dc as Dc) as Void {
        if (_hudBuffer != null) {
            dc.drawBitmap(0, 0, _hudBuffer);
        } else {
            drawStaticHud(dc);
        }
    }

    private function loadTimeFonts(dc as Dc) as Void {
        _timeFontsLoaded = true;
        _timeCacheText = null;
        var index = Properties.getValue("TimeFont");
        if (!(index instanceof Number) || index < 0 || index >= TIME_FONT_FACES.size()) {
            index = 0;
        }
        var faces = [TIME_FONT_FACES[index] as String, TIME_FONT_FACES[0] as String];

        var font = Graphics.getVectorFont({ :face => faces, :size => TIME_FONT_SIZE });
        if (font == null) {
            _timeFont = null;
            _timeFontSmall = null;
            return;
        }

        // Shrink the font when a face is too wide for the space between the date and the weather.
        var shortWidth = dc.getTextWidthInPixels("0:00", font);
        var longWidth = dc.getTextWidthInPixels("00:00", font);
        _timeFont = shortWidth <= TIME_MAX_WIDTH
            ? font
            : Graphics.getVectorFont({ :face => faces, :size => (TIME_FONT_SIZE * TIME_MAX_WIDTH) / shortWidth });
        _timeFontSmall = longWidth <= TIME_MAX_WIDTH
            ? font
            : Graphics.getVectorFont({ :face => faces, :size => (TIME_FONT_SIZE * TIME_MAX_WIDTH) / longWidth });
    }

    // The bold time is drawn six times over, so render it once per change into a white image.
    private function renderTimeCache(font as Graphics.FontType, text as String) as Void {
        if (_timeCache == null) {
            _timeCache = Graphics.createBufferedBitmap({
                :width => TIME_CACHE_WIDTH,
                :height => TIME_CACHE_HEIGHT
            }).get() as BufferedBitmap;
        }
        var cacheDc = (_timeCache as BufferedBitmap).getDc();
        cacheDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        cacheDc.clear();
        cacheDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var top = TIME_CENTER_Y - (TIME_DIGIT_CENTER * Graphics.getFontAscent(font)).toNumber();
        drawBoldText(cacheDc, 140 - TIME_CACHE_LEFT, top - TIME_CACHE_TOP, font, text);
        _timeCacheText = text;
    }

    private function drawBoldText(dc as Dc, x as Number, y as Number, font as Graphics.FontType, text as String) as Void {
        for (var dx = -1; dx <= 1; dx++) {
            dc.drawText(x + dx, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(x + dx, y + 1, font, text, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawBattery(dc as Dc, battery as Number, batteryInDays as Numeric, charging as Boolean) as Void {
        var level = battery;
        if (level < 0) {
            level = 0;
        } else if (level > 100) {
            level = 100;
        }

        // iOS system green; the 64-colour display shows its nearest shade.
        var color = 0x34C759;
        if (level < 15) {
            color = Graphics.COLOR_RED;
        } else if (level < 30) {
            color = Graphics.COLOR_ORANGE;
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(123, 9, 24, 12);
        dc.fillRectangle(147, 12, 3, 6);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(125, 11, (20 * level) / 100, 8);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(154, 6, _telemetryFont == null ? Graphics.FONT_SYSTEM_XTINY : _telemetryFont,
            batteryInDays.format("%.0f") + "d", Graphics.TEXT_JUSTIFY_LEFT);

        if (charging && _chargingIcon != null) {
            dc.drawBitmap(131, 9, _chargingIcon);
        }
    }

    // Fraction of the lunar cycle: 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
    private function getMoonPhase(moment as Time.Moment) as Float {
        var cyclePosition = (moment.value() - KNOWN_NEW_MOON) % SYNODIC_MONTH_SECONDS;
        return cyclePosition.toFloat() / SYNODIC_MONTH_SECONDS;
    }

    // Anti-aliased moon. Each row is filled as solid lit/dark runs; only pixels within one pixel
    // of the rim or the terminator get exact coverage (averaged over four sub-rows), blended with
    // the sky and dithered to the 64-colour palette. Maria are dithered over the lit runs.
    private function drawMoon(dc as Dc, centerX as Number, centerY as Number, phase as Float) as Void {
        var r = MOON_RADIUS.toFloat();
        var terminator = Math.cos(2 * Math.PI * phase).toFloat();
        var waxing = phase < 0.5;
        var reach = MOON_RADIUS + 1;
        var skyHeight = dc.getHeight() - SKY_TOP;
        var offsets = [-0.375, -0.125, 0.125, 0.375];
        var litColor = rgbToColor(MOON_LIT_RGB);
        // Dark runs are black with navy dithered in to reach MOON_DARK_RGB.
        var darkColor = 0x000000;
        var darkShare = (MOON_DARK_RGB[2] as Number) / 85.0;
        // Share of mare pixels drawn in the darker palette yellow (0xAAAA55) to average MOON_MARE_RGB.
        var mareShare = (255 - (MOON_MARE_RGB[0] as Number)) / 85.0;

        var chords = new [4];
        var boundaries = new [4];
        for (var py = -reach; py <= reach; py++) {
            var y = centerY + py;
            var halfChord = terminatorX(py.toFloat(), r, 1.0, true);
            if ((py * py) > (r + 0.5) * (r + 0.5)) {
                continue;
            }
            var boundary = waxing ? terminator * halfChord : -terminator * halfChord;
            for (var i = 0; i < 4; i++) {
                var sy = py + (offsets[i] as Float);
                var squared = (r * r) - (sy * sy);
                var chord = squared > 0 ? Math.sqrt(squared).toFloat() : -1.0;
                chords[i] = chord;
                boundaries[i] = waxing ? terminator * chord : -terminator * chord;
            }

            var skyBlue = (85 * skyLevel(y, skyHeight)) / 16.0;
            var thresholds = SKY_DITHER[y % 4] as Array<Number>;
            var runStart = 0;
            var runColor = -1;
            for (var px = -reach; px <= reach + 1; px++) {
                var color = -1;
                var solid = px <= reach
                    && (px - halfChord).abs() > 1.0 && (px + halfChord).abs() > 1.0 && (px - boundary).abs() > 1.0
                    && px.abs() < halfChord;
                if (solid) {
                    color = (waxing ? px > boundary : px < boundary) ? litColor : darkColor;
                }
                if (color != runColor) {
                    if (runColor != -1) {
                        dc.setColor(runColor, Graphics.COLOR_TRANSPARENT);
                        dc.fillRectangle(centerX + runStart, y, px - runStart, 1);
                        if (runColor == darkColor) {
                            dc.setColor(0x000055, Graphics.COLOR_TRANSPARENT);
                            for (var dx = runStart; dx < px; dx++) {
                                if ((thresholds[(centerX + dx) % 4] + 0.5) / 16.0 < darkShare) {
                                    dc.drawPoint(centerX + dx, y);
                                }
                            }
                        }
                    }
                    runStart = px;
                    runColor = color;
                }
                if (solid || px > reach) {
                    continue;
                }

                // Edge pixel: exact coverage of the lit and dark intervals per sub-row.
                var lit = 0.0;
                var dark = 0.0;
                for (var i = 0; i < 4; i++) {
                    var chord = chords[i] as Float;
                    if (chord <= 0) {
                        continue;
                    }
                    var edge = boundaries[i] as Float;
                    if (waxing) {
                        lit += overlap(px, edge, chord);
                        dark += overlap(px, -chord, edge);
                    } else {
                        lit += overlap(px, -chord, edge);
                        dark += overlap(px, edge, chord);
                    }
                }
                lit /= 4.0;
                dark /= 4.0;
                if (lit + dark <= 0.01) {
                    continue;
                }

                var sky = 1.0 - lit - dark;
                var threshold = (thresholds[(centerX + px) % 4] + 0.5) / 16.0;
                var blended = 0;
                for (var channel = 0; channel < 3; channel++) {
                    var value = (lit * (MOON_LIT_RGB[channel] as Number))
                        + (dark * (MOON_DARK_RGB[channel] as Number))
                        + (channel == 2 ? sky * skyBlue : 0.0);
                    blended = (blended << 8) | quantizeChannel(value, threshold);
                }
                dc.setColor(blended, Graphics.COLOR_TRANSPARENT);
                dc.drawPoint(centerX + px, y);
            }

            // Maria: dither darker yellow over solid lit pixels inside each mare.
            dc.setColor(0xAAAA55, Graphics.COLOR_TRANSPARENT);
            for (var m = 0; m < MOON_MARIA.size(); m++) {
                var mare = MOON_MARIA[m] as Array<Float>;
                var dy = (py / r) - mare[1];
                var spread = (mare[2] * mare[2]) - (dy * dy);
                if (spread <= 0) {
                    continue;
                }
                var halfWidth = Math.sqrt(spread).toFloat() * r;
                var from = Math.round((mare[0] * r) - halfWidth).toNumber();
                var to = Math.round((mare[0] * r) + halfWidth).toNumber();
                for (var px = from; px <= to; px++) {
                    var inside = px.abs() < halfChord - 1.0 && (px - boundary).abs() > 1.0
                        && (waxing ? px > boundary : px < boundary);
                    if (inside && (thresholds[(centerX + px) % 4] + 0.5) / 16.0 < mareShare) {
                        dc.drawPoint(centerX + px, y);
                    }
                }
            }
        }
    }

    // Length of [from, to] that falls inside pixel px, which spans [px - 0.5, px + 0.5].
    private function overlap(px as Number, from as Float, to as Float) as Float {
        var low = from > px - 0.5 ? from : px - 0.5;
        var high = to < px + 0.5 ? to : px + 0.5;
        return high > low ? high - low : 0.0;
    }

    private function rgbToColor(rgb as Array) as Number {
        return ((rgb[0] as Number) << 16) | ((rgb[1] as Number) << 8) | (rgb[2] as Number);
    }

    // Horizontal position of the day/night line at height y; lit side is right of it when waxing.
    private function terminatorX(y as Float, r as Float, terminator as Float, waxing as Boolean) as Float {
        var squared = (r * r) - (y * y);
        var halfChord = squared > 0 ? Math.sqrt(squared).toFloat() : 0.0;
        return waxing ? terminator * halfChord : -terminator * halfChord;
    }

    // Ordered-dither one 0-255 channel to the four display levels 0, 85, 170, 255.
    private function quantizeChannel(value as Float, threshold as Float) as Number {
        var level = value / 85.0;
        var base = level.toNumber();
        if (base < 3 && level - base > threshold) {
            base += 1;
        }
        return base * 85;
    }

    private function drawSolarIntensity(dc as Dc, intensity as Number?) as Void {
        dc.setPenWidth(5);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(140, 140, 134, Graphics.ARC_COUNTER_CLOCKWISE, 335, 25);

        if (intensity != null && intensity >= 0) {
            var level = intensity;
            if (level > 100) {
                level = 100;
            }

            if (level > 0) {
                var sweep = (50 * level) / 100;
                if (sweep < 1) {
                    sweep = 1;
                }

                dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(140, 140, 134, Graphics.ARC_COUNTER_CLOCKWISE, 335, (335 + sweep) % 360);
            }
        }

        dc.setPenWidth(1);
    }

    // Arrow then time, starting at x.
    private function drawSolarTime(dc as Dc, x as Number, y as Number, value as String, isSunrise as Boolean) as Void {
        var headerFont = _headerFont == null ? Graphics.FONT_SYSTEM_XTINY : _headerFont;
        var arrowX = x + 3;
        var arrowTop = y + 5;
        var arrowBottom = y + 14;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 10, y, headerFont, value, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawLine(arrowX, arrowTop, arrowX, arrowBottom);

        if (isSunrise) {
            dc.drawLine(arrowX, arrowTop, arrowX - 3, arrowTop + 3);
            dc.drawLine(arrowX, arrowTop, arrowX + 3, arrowTop + 3);
        } else {
            dc.drawLine(arrowX, arrowBottom, arrowX - 3, arrowBottom - 3);
            dc.drawLine(arrowX, arrowBottom, arrowX + 3, arrowBottom - 3);
        }
    }

    private function drawWeatherIcon(dc as Dc, condition as Complications.Value?) as Void {
        var icon = getWeatherIcon(condition);
        if (icon != null) {
            dc.drawBitmap(119, 19, icon);
        }
    }

    private function formatTemperature(value as Complications.Value?) as String {
        if (value == null) {
            return "--";
        }

        var temperature = value as Numeric;
        var unit = "C";
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            temperature = (temperature * 9.0 / 5.0) + 32.0;
            unit = "F";
        }
        return temperature.format("%.0f") + "°" + unit;
    }

    private function formatWind(conditions as Weather.CurrentConditions?) as String {
        if (conditions == null || conditions.windSpeed == null) {
            return "--";
        }

        var speed = conditions.windSpeed as Float;
        var text = "";
        var bearing = conditions.windBearing;
        if (bearing != null) {
            var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
            text = directions[((bearing + 22) / 45) % 8] + " ";
        }
        if (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE) {
            return text + (speed * 2.23694).format("%.0f") + "mph";
        }
        return text + (speed * 3.6).format("%.0f") + "km/h";
    }

    private function drawDate(dc as Dc, weekday as String, day as String, month as String) as Void {
        if (_dateFont != null) {
            var text = month + " " + day + ", " + weekday;
            dc.drawText(140, 74, _dateFont, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function getWeatherIcon(condition as Complications.Value?) as BitmapResource? {
        if (condition == null || _weatherIcons.size() == 0) {
            return null;
        }

        var weatherCondition = condition as Number;
        var daytime = isDaytime();

        switch (weatherCondition) {
            case Weather.CONDITION_CLEAR:
            case Weather.CONDITION_FAIR:
            case Weather.CONDITION_MOSTLY_CLEAR:
                return _weatherIcons[daytime ? 0 : 1];
            case Weather.CONDITION_PARTLY_CLEAR:
            case Weather.CONDITION_PARTLY_CLOUDY:
            case Weather.CONDITION_THIN_CLOUDS:
                return _weatherIcons[daytime ? 7 : 5];
            case Weather.CONDITION_MOSTLY_CLOUDY:
            case Weather.CONDITION_CLOUDY:
                return _weatherIcons[2];
            case Weather.CONDITION_FOG:
            case Weather.CONDITION_HAZY:
            case Weather.CONDITION_MIST:
            case Weather.CONDITION_DUST:
            case Weather.CONDITION_SMOKE:
            case Weather.CONDITION_SAND:
            case Weather.CONDITION_SANDSTORM:
            case Weather.CONDITION_VOLCANIC_ASH:
            case Weather.CONDITION_HAZE:
                return _weatherIcons[3];
            case Weather.CONDITION_HEAVY_SNOW:
                return _weatherIcons[13];
            case Weather.CONDITION_SNOW:
            case Weather.CONDITION_LIGHT_SNOW:
            case Weather.CONDITION_CHANCE_OF_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW:
            case Weather.CONDITION_FLURRIES:
                return _weatherIcons[9];
            case Weather.CONDITION_THUNDERSTORMS:
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
            case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS:
                return _weatherIcons[10];
            case Weather.CONDITION_WINDY:
            case Weather.CONDITION_SQUALL:
            case Weather.CONDITION_TORNADO:
            case Weather.CONDITION_HURRICANE:
            case Weather.CONDITION_TROPICAL_STORM:
                return _weatherIcons[11];
            case Weather.CONDITION_WINTRY_MIX:
            case Weather.CONDITION_LIGHT_RAIN_SNOW:
            case Weather.CONDITION_HEAVY_RAIN_SNOW:
            case Weather.CONDITION_RAIN_SNOW:
            case Weather.CONDITION_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_HAIL:
            case Weather.CONDITION_ICE:
            case Weather.CONDITION_FREEZING_RAIN:
            case Weather.CONDITION_SLEET:
            case Weather.CONDITION_ICE_SNOW:
                return _weatherIcons[4];
            case Weather.CONDITION_HEAVY_RAIN:
                return _weatherIcons[12];
            case Weather.CONDITION_RAIN:
            case Weather.CONDITION_SCATTERED_SHOWERS:
            case Weather.CONDITION_UNKNOWN_PRECIPITATION:
            case Weather.CONDITION_LIGHT_RAIN:
            case Weather.CONDITION_LIGHT_SHOWERS:
            case Weather.CONDITION_SHOWERS:
            case Weather.CONDITION_HEAVY_SHOWERS:
            case Weather.CONDITION_CHANCE_OF_SHOWERS:
            case Weather.CONDITION_DRIZZLE:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN:
                return _weatherIcons[daytime ? 8 : 6];
            default:
                return _weatherIcons[2];
        }
    }

    private function isDaytime() as Boolean {
        var sunrise = Complications.getComplication(_sunriseId).value;
        var sunset = Complications.getComplication(_sunsetId).value;
        if (sunrise == null || sunset == null) {
            return true;
        }

        var clockTime = System.getClockTime();
        var secondsSinceMidnight = (clockTime.hour * 3600) + (clockTime.min * 60) + clockTime.sec;
        return secondsSinceMidnight >= (sunrise as Number) && secondsSinceMidnight < (sunset as Number);
    }

    private function getLatestSensorValue(methodSymbol as Symbol) as Numeric? {
        if (!(SensorHistory has methodSymbol)) {
            return null;
        }

        var getHistory = new Lang.Method(SensorHistory, methodSymbol);
        var iterator = getHistory.invoke({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        }) as SensorHistoryIterator;
        var sample = iterator.next();

        return sample == null ? null : sample.data;
    }

    private function getBodyBattery() as Numeric? {
        if (!(SensorHistory has :getBodyBatteryHistory)) {
            return _lastBodyBattery;
        }

        var iterator = SensorHistory.getBodyBatteryHistory({
            :period => 8,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        var sample = iterator.next();

        while (sample != null) {
            var value = sample.data;
            if (value != null && value >= 0 && value <= 100) {
                _lastBodyBattery = value;
                break;
            }
            sample = iterator.next();
        }

        return _lastBodyBattery;
    }

    private function formatValue(value as Numeric?, format as String) as String {
        return value == null ? "--" : value.format(format);
    }

    private function formatHeartRate(current as Numeric?, maximum as Numeric?) as String {
        return Lang.format("$1$/$2$", [formatValue(current, "%d"), formatValue(maximum, "%d")]);
    }

    private function formatCalories(calories as Numeric?) as String {
        if (calories == null || calories < 1000) {
            return formatValue(calories, "%d");
        }
        // Truncate to one decimal so 2875 reads as 2.8k.
        return ((calories.toNumber() / 100) / 10.0).format("%.1f") + "k";
    }

    private function formatDistance(distance as Numeric?) as String {
        if (distance == null) {
            return "--";
        }

        if (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE) {
            return (distance.toFloat() / 160934.4).format("%.1f") + "mi";
        }
        return (distance.toFloat() / 100000.0).format("%.1f") + "km";
    }

    private function drawSummary(dc as Dc, text as String) as Void {
        if (_summaryFonts.size() == 0) {
            return;
        }

        // Use the largest size that fits the narrow space above the bottom edge; re-measure only when the text changes.
        if (_summaryFont == null || !text.equals(_summaryText)) {
            _summaryFont = _summaryFonts[_summaryFonts.size() - 1];
            for (var i = 0; i < _summaryFonts.size(); i++) {
                if (dc.getTextWidthInPixels(text, _summaryFonts[i]) <= SUMMARY_MAX_WIDTH) {
                    _summaryFont = _summaryFonts[i];
                    break;
                }
            }
            _summaryText = text;
        }
        dc.drawText(140, 226, _summaryFont as Graphics.VectorFont, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function getSolarTime(id as Complications.Id) as String {
        var value = Complications.getComplication(id).value;
        if (value == null) {
            return "--:--";
        }

        var seconds = value as Number;
        var hours = seconds / 3600;
        var minutes = (seconds % 3600) / 60;
        return Lang.format("$1$:$2$", [hours.format("%02d"), minutes.format("%02d")]);
    }
}
