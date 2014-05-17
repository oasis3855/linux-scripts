#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Ubuntu Gnome indicator applet of weather
# 天気をGnomeインジケータに表示するアプレット for Ubuntu Linux
#
# (C) 2014 INOUE Hirokazu
# GNU GPL Free Software (GPL Version 2)
#
# Version 0.1 (2014/05/11)
# Version 0.2 (2014/05/12)
# Version 0.3 (2014/05/17)

import sys
import pygtk
pygtk.require('2.0')
import gtk
import datetime
import os
import ConfigParser
import gobject
import appindicator
import pywapi       # Python天気API (yahoo.comとweather.com用)
                     # https://code.google.com/p/python-weather-api/
import urllib       # OpenWeatherMap.org用
import json

#####
# GLOBAL VAR

# Station ID of weather.com/yahoo.com (ex. Tokyo = JAXX0085, Osaka = JAXX0071, New York = USNY0996)
# Station ID of OpenWeatherMap.org (ex. Tokyo = 1850147, Osaka = 1853909, New York = 5128638)
STATION_ID = '1850147'
# 環境省 大気汚染物質広域監視システム「そらまめ君」の観測値ID (ex 千代田区神田司町= 13101010, 国設大阪 = 27115010)
SORAMAME_STATION_ID = '13101010'
# 「そらまめ君」を受信する場合 True
FLAG_SORAMAME_ENABLE = False
# チェックする間隔（秒）
CHECK_INTERVAL_SEC =  900    # sec
# 接続先 (YAHOO.COM or WEATHER.COM or OPENWEATHERMAP.COM)
WEB_SERVICE = 'OPENWEATHERMAP.COM'

class WeatherIndicator:
    def __init__(self):
        self.ind = appindicator.Indicator ("user-weather-indicator",
                    "indicator-messages",       # STATUS_ACTIVE のアイコンを設定
                    appindicator.CATEGORY_APPLICATION_STATUS)
        self.ind.set_status (appindicator.STATUS_ACTIVE)
        self.ind.set_attention_icon ("weather-severe-alert")
        self.ind.set_label("--℃")
        self.ind.set_icon("weather-severe-alert")

        # コンテキストメニュー 設定
        self.menu_setup()
        self.ind.set_menu(self.menu)

        # 設定ファイルの読み込み
        self.config_file_read()

    #####
    # コンテキストメニュー 設定（クラスのコンストラクタから呼び出される）
    def menu_setup(self):
        self.menu = gtk.Menu()

        self.checknow_item = gtk.MenuItem("今すぐ天気データを受信")
        self.checknow_item.connect("activate", self.menu_check_now)
        self.checknow_item.show()
        self.menu.append(self.checknow_item)

        # データ表示部
        self.data_item = gtk.MenuItem('-----')
        self.data_item.set_sensitive(False)     # このメニューは選択できない
        self.data_item.show()
        self.menu.append(self.data_item)
        # 仕切り線
        breaker = gtk.SeparatorMenuItem()
        breaker.show()
        self.menu.append(breaker)

        # 設定表示部
        self.data2_item = gtk.MenuItem("接続先:%s\n更新間隔(秒):%s\n場所ID:%s" % (WEB_SERVICE, str(CHECK_INTERVAL_SEC), STATION_ID))
        self.data2_item.set_sensitive(False)     # このメニューは選択できない
        self.data2_item.show()
        self.menu.append(self.data2_item)
        # 仕切り線
        breaker = gtk.SeparatorMenuItem()
        breaker.show()
        self.menu.append(breaker)

        # 設定表示部（「そらまめ君」用）
        self.data3_item = gtk.MenuItem('---')
        self.data3_item.set_sensitive(False)     # このメニューは選択できない
        self.data3_item.show()
        self.menu.append(self.data3_item)
        # 仕切り線
        breaker = gtk.SeparatorMenuItem()
        breaker.show()
        self.menu.append(breaker)

        # 設定メニュー
        self.config_item = gtk.ImageMenuItem("設定")
        self.config_item.set_image(gtk.image_new_from_stock('gtk-preferences', gtk.ICON_SIZE_MENU))
        self.config_item.connect("activate", self.menu_config_dialog)
        self.config_item.show()
        self.menu.append(self.config_item)

        # About表示メニュー
        self.show_about_item = gtk.MenuItem("このプログラムについて")
        self.show_about_item.connect("activate", self.menu_about_dlg)
        self.show_about_item.show()
        self.menu.append(self.show_about_item)

        # 終了メニュー
        self.quit_item = gtk.ImageMenuItem("終了")
        self.quit_item.set_image(gtk.image_new_from_stock('gtk-quit', gtk.ICON_SIZE_MENU))
        self.quit_item.connect("activate", self.menu_quit)
        self.quit_item.show()
        self.menu.append(self.quit_item)

    #####
    # メニュー ： Aboutダイアログ
    def menu_about_dlg(self, widget):
        dlg = gtk.MessageDialog(type=gtk.MESSAGE_INFO, buttons=gtk.BUTTONS_OK, message_format='天気インジケータ')
        dlg.format_secondary_text('現在の天気を表示します')
        dlg.run()
        dlg.destroy()

    #####
    # メニュー ： 今すぐ受信
    def menu_check_now(self, widget):
        self.get_weather()

    #####
    # メニュー ： プログラム終了
    def menu_quit(self, widget, data=None):
        gtk.main_quit()

    #####
    # メニュー ： 設定ダイアログ
    def menu_config_dialog(self, widget):
        global STATION_ID, WEB_SERVICE, CHECK_INTERVAL_SEC, SORAMAME_STATION_ID, FLAG_SORAMAME_ENABLE
        dlg = gtk.MessageDialog(type=gtk.MESSAGE_INFO, buttons=gtk.BUTTONS_OK_CANCEL, message_format='天気インジケータ')
        dlg.format_secondary_text('天気データ取得方法を設定します')

        dlg_content = dlg.get_content_area()
        hbox_server = gtk.HBox()
        hbox_server.add(gtk.Label('サーバ名'))
        servers = ['YAHOO.COM', 'WEATHER.COM', 'OPENWEATHERMAP.COM']
        list_server = gtk.ListStore(gobject.TYPE_STRING)
        for item in servers:
            list_server.append([item])
        cell_server = gtk.CellRendererText()
        combobox_server = gtk.ComboBox(list_server)
        combobox_server.pack_start(cell_server, True)
        combobox_server.add_attribute(cell_server, 'text', 0)
        combobox_server.set_active(servers.index(WEB_SERVICE))
        hbox_server.add(combobox_server)

        hbox_stationid = gtk.HBox()
        hbox_stationid.add(gtk.Label('観測地 ID'))
        text_entry_stationid = gtk.Entry()
        text_entry_stationid.set_width_chars(30)
        text_entry_stationid.set_text(STATION_ID)
        hbox_stationid.add(text_entry_stationid)

        hbox_interval = gtk.HBox()
        hbox_interval.add(gtk.Label('チエック周期（秒）'))
        adj_interval = gtk.Adjustment(value=CHECK_INTERVAL_SEC, lower=600, upper=3600, step_incr=60)
        hbox_interval.add(gtk.SpinButton(adj_interval, 0))

        hbox_soramame = gtk.HBox()
        check_soramame = gtk.CheckButton('環境省「そらまめ君」を受信する')
        if(FLAG_SORAMAME_ENABLE == True):
            check_soramame.set_active(True)
        hbox_soramame.add(check_soramame)

        hbox_soramameid = gtk.HBox()
        hbox_soramameid.add(gtk.Label('そらまめ君 観測局 ID'))
        text_entry_soramameid = gtk.Entry()
        text_entry_soramameid.set_width_chars(20)
        text_entry_soramameid.set_text(SORAMAME_STATION_ID)
        hbox_soramameid.add(text_entry_soramameid)

        dlg_content.add(hbox_server)
        dlg_content.add(hbox_stationid)
        dlg_content.add(hbox_interval)
        dlg_content.add(hbox_soramame)
        dlg_content.add(hbox_soramameid)
        dlg.show_all()
        ret = dlg.run()

        text_server = combobox_server.get_active_text().decode('utf8')
        text_stationid = text_entry_stationid.get_text().decode('utf8')
        int_interval = int(adj_interval.get_value())
        text_soramameid = text_entry_soramameid.get_text().decode('utf8')
        flag_soramame = check_soramame.get_active()
        dlg.destroy()

        if ret == gtk.RESPONSE_OK:
            WEB_SERVICE = text_server
            STATION_ID = text_stationid
            CHECK_INTERVAL_SEC = int_interval
            if CHECK_INTERVAL_SEC < 600 or 3600 < CHECK_INTERVAL_SEC:
                CHECK_INTERVAL_SEC = 900
            SORAMAME_STATION_ID = text_soramameid
            if(flag_soramame):
                FLAG_SORAMAME_ENABLE = True
            else:
                FLAG_SORAMAME_ENABLE = False
            self.config_file_write()
            self.get_weather()

    #####
    # メイン関数（タイマー設定を行う）
    def main(self):
        global CHECK_INTERVAL_SEC
        # まずはじめに、天候データの受信
        self.get_weather()
        # タイマー設定（定期的に check_mail 関数を実行する）
        gtk.timeout_add(CHECK_INTERVAL_SEC * 1000, self.get_weather)
        gtk.main()

    #####
    # 天気データの受信と、パネルとコンテキストメニュー表示を更新
    def get_weather(self):
        global STATION_ID, WEB_SERVICE, CHECK_INTERVAL_SEC

        try:
            weather_text = ''
            weather = Weather()
            if WEB_SERVICE == 'WEATHER.COM':
                result = pywapi.get_weather_from_weather_com(STATION_ID, 'metric')
                # パネルのアイコンと温度表示
                self.ind.set_icon(weather.get_icon_name(str(result['current_conditions']['icon']), False))
                self.ind.set_label(str(result['current_conditions']['temperature']) + '℃')
                # データを読み出す
                weather_text = "場所:%s\n天候:%s\n気温:%s\n湿度:%s\n気圧:%s\nデータ日時:%s" % (
                                result['current_conditions']['station'],
                                result['current_conditions']['text'],
                                result['current_conditions']['temperature'],
                                result['current_conditions']['humidity'],
                                result['current_conditions']['barometer']['reading'],
                                result['current_conditions']['last_updated'])
            elif WEB_SERVICE == 'YAHOO.COM':
                result = pywapi.get_weather_from_yahoo(STATION_ID, 'metric')
                # パネルのアイコンと温度表示
                self.ind.set_icon(weather.get_icon_name(str(result['condition']['code']), False))
                self.ind.set_label(str(result['condition']['temp']) + '℃')
                # データを読み出す
                weather_text = "場所:%s\n天候:%s\n気温:%s\n湿度:%s\n気圧:%s\nデータ日時:%s" % (
                                result['location']['city'],
                                result['condition']['text'],
                                result['condition']['temp'],
                                result['atmosphere']['humidity'],
                                result['atmosphere']['pressure'],
                                result['condition']['date'])
            elif WEB_SERVICE == 'OPENWEATHERMAP.COM':
                url = 'http://api.openweathermap.org/data/2.5/weather?units=metric&id=' + STATION_ID
                json_tree = json.loads(urllib.urlopen(url).read())
                # 受信エラーの場合
                if(str(json_tree['cod']) != '200'):
                    self.ind.set_icon('weather-severe-alert')   # エラー時の「雨＋警報」アイコン
                    self.ind.set_label('--℃')
                    weather_text = "接続エラー"
                else:
                    # パネルのアイコンと温度表示
                    self.ind.set_icon(weather.get_icon_name(json_tree['weather'][0]['icon'], False))
                    self.ind.set_label(str(round(json_tree['main']['temp'], 1)) + '℃')
                    # データを読み出す
                    weather_text = "場所:%s\n天候:%s\n気温:%s\n湿度:%s\n気圧:%s\nデータ日時:%s" % (
                                    json_tree['name'],
                                    json_tree['weather'][0]['description'],
                                    str(json_tree['main']['temp']),
                                    str(json_tree['main']['humidity']),
                                    str(json_tree['main']['pressure']),
                                    datetime.datetime.fromtimestamp(json_tree['dt']).strftime(u'%Y/%m/%d %H:%M:%S'))
            else:
                self.ind.set_icon('weather-severe-alert')   # エラー時の「雨＋警報」アイコン
                self.ind.set_label('--℃')
            # コンテキストメニューのデータ表示部を更新
            weather_text = weather_text + ("\nネット接続:%s" % (datetime.datetime.now().strftime(u'%Y/%m/%d %H:%M:%S')))
            self.data_item.set_label(weather_text)
        except:
                self.ind.set_icon('weather-severe-alert')   # エラー時の「雨＋警報」アイコン
                self.ind.set_label('--℃')
                # コンテキストメニューのデータ表示部を更新
                self.data_item.set_label("接続エラー\nネット接続:%s" % (datetime.datetime.now().strftime(u'%Y/%m/%d %H:%M:%S')))

        self.data2_item.set_label("接続先:%s\n更新間隔(秒):%s\n場所ID:%s" % (WEB_SERVICE, str(CHECK_INTERVAL_SEC), STATION_ID))

        self.get_soramamekun()

        return True

    #####
    # 環境省「そらまめ君」データの受信と、パネルとコンテキストメニュー表示を更新
    def get_soramamekun(self):
        global SORAMAME_STATION_ID, FLAG_SORAMAME_ENABLE

        if(FLAG_SORAMAME_ENABLE != True):
            return True

        try:
            url = 'http://www.obccbo.com/soramame/v1/weeks/' + SORAMAME_STATION_ID + '.json '
            json_tree = json.loads( urllib.urlopen(url).read() )

            # statusがOK以外、あるいはデータ個数が24以下の場合異常判定
            if(str(json_tree['status']) != 'OK' or len(json_tree['data']) <= 24):
                self.data_item.set_label('環境省データ：受信データ異常')
                return True

            # 最新のデータのインデックスを求める
            i_new = 0
            d_new = datetime.datetime(int(json_tree['data'][0]['year']), int(json_tree['data'][0]['month']),
                    int(json_tree['data'][0]['day']), int(json_tree['data'][0]['time'][0:2]))
            for i in range(len(json_tree['data'])):
                # 大気汚染物質広域監視システムの時間表記が 01時〜24時であるため、0時から始まるよう修正
                hour_tmp = int(json_tree['data'][i]['time'][0:2])
                if hour_tmp >= 24:
                    hour_tmp = 0
                # datetime型に代入して、比較する（より新しいタイムスタンプのindexを取り出す）
                d = datetime.datetime(int(json_tree['data'][i]['year']), int(json_tree['data'][i]['month']),
                    int(json_tree['data'][i]['day']), hour_tmp)
                if(d > d_new):
                    d_new = d
                    i_new = i

            d = datetime.datetime(int(json_tree['data'][i_new]['year']), int(json_tree['data'][i_new]['month']),
                    int(json_tree['data'][i_new]['day']), int(json_tree['data'][i_new]['time'][0:2]))

            # データを読み出す
            weather_text = "環境省「そらまめ君」\n観測局ID:%s\nデータ日時:%s\n気温:%s\n湿度:%s\n風速:%s\nPM2.5:%s\nNOx:%s\nSO2:%s\n光化学Ox:%s" % (
                            SORAMAME_STATION_ID,
                            d.strftime("%Y/%m/%d %H:%M:%S"),
                            json_tree['data'][i_new]['temp'],
                            json_tree['data'][i_new]['hum'],
                            (json_tree['data'][i_new]['ws'] + ' (m/sec)'),
                            (json_tree['data'][i_new]['pm2.5'] + ' (ug/m3)'),
                            (json_tree['data'][i_new]['nox'] + ' (ppm)'),
                            (json_tree['data'][i_new]['so2'] + ' (ppm)'),
                            (json_tree['data'][i_new]['so2'] + ' (ppm)'))
            self.data3_item.set_label(weather_text)
            # Gnomeパネルの文字を更新（たとえば、PM2.5濃度を表示する場合）
            self.ind.set_label(json_tree['data'][i_new]['temp'] + '℃  ' + json_tree['data'][i_new]['pm2.5'] + 'ug/m3')

        except:
            # コンテキストメニューのデータ表示部を更新
            self.data3_item.set_label('環境省データ：接続エラー')

        return True

    #####
    # 設定ファイルに書き込む
    def config_file_write(self):
        global STATION_ID, WEB_SERVICE, CHECK_INTERVAL_SEC, SORAMAME_STATION_ID, FLAG_SORAMAME_ENABLE
        parser = ConfigParser.SafeConfigParser()
        configfile = os.path.join(os.environ['HOME'], '.weather-indicator')

        try:
            fp = open(configfile, 'w')
            parser.set("DEFAULT", "station_id", STATION_ID)
            parser.set("DEFAULT", "web_service", WEB_SERVICE)
            parser.set("DEFAULT", "interval_sec", str(CHECK_INTERVAL_SEC))
            parser.set("DEFAULT", "soramame_station_id", SORAMAME_STATION_ID)
            if FLAG_SORAMAME_ENABLE == True:
                parser.set("DEFAULT", "soramame_flag", 'True')
            else:
                parser.set("DEFAULT", "soramame_flag", 'False')

            parser.write(fp)
            fp.close()
        except IOError:
            print >> sys.stderr, "config write error"

    #####
    # 設定ファイルから読み込む
    def config_file_read(self):
        global STATION_ID, WEB_SERVICE, CHECK_INTERVAL_SEC, SORAMAME_STATION_ID, FLAG_SORAMAME_ENABLE
        parser = ConfigParser.SafeConfigParser({
                'station_id' : STATION_ID,
                'web_service' : WEB_SERVICE,
                'interval_sec' : str(CHECK_INTERVAL_SEC),
                'soramame_station_id' : SORAMAME_STATION_ID,
                'soramame_flag' : 'True' if FLAG_SORAMAME_ENABLE != True else 'False'
            })
        configfile = os.path.join(os.environ['HOME'], '.weather-indicator')

        try:
            fp = open(configfile, 'r')
            parser.readfp(fp)
            fp.close()
            STATION_ID = parser.get("DEFAULT", "station_id")
            WEB_SERVICE = parser.get("DEFAULT", "web_service")
            CHECK_INTERVAL_SEC = int(parser.get("DEFAULT", "interval_sec"))
            # CHECK_INTERVAL_SEC : from 1min to 30min, default 5min
            if CHECK_INTERVAL_SEC < 600 or 3600 < CHECK_INTERVAL_SEC:
                CHECK_INTERVAL_SEC = 900
            SORAMAME_STATION_ID = parser.get("DEFAULT", "soramame_station_id")
            flag = parser.get("DEFAULT", "soramame_flag")
            FLAG_SORAMAME_ENABLE = True if flag == 'True' else  False
        except:
            # 設定ファイルが読み込めない場合、書き込みを行う（新規作成の時を意図）
            print >> sys.stderr, "config file error (not found or syntax error)"
            self.config_file_write()
            return


# 天気アイコンNoを、Gnomeアイコン名に変換するクラス
class Weather:
    """Data object to parse weather data with unit conversion """
    global STATION_ID, WEB_SERVICE
# weather-indicator(GPL) の Weatherクラスのディクショナリ変数定義部分を流用
# https://launchpad.net/weather-indicator

    # Available conditions by yahoo condition code
    # Format: condition code: (day icon, night icon, is a severe weather condition, localized condition name)
    _YahooConditions = {
        '0' : ("weather-storm",             "weather-storm",            True,  "Tornado"),
        '1' : ("weather-storm",             "weather-storm",            True,  "Tropical storm"),
        '2' : ("weather-storm",             "weather-storm",            True,  "Hurricane"),
        '3' : ("weather-storm",             "weather-storm",            True,  "Severe thunderstorms"),
        '4' : ("weather-storm",             "weather-storm",            True,  "Thunderstorms"),
        '5' : ("weather-snow",              "weather-snow",             False, "Mixed rain and snow"),
        # Use American meaning of sleet - see http://en.wikipedia.org/wiki/Sleet
        '6' : ("weather-showers",           "weather-showers",          False, "Mixed rain and sleet"),
        '7' : ("weather-snow",              "weather-snow",             False, "Mixed snow and sleet"),
        '8' : ("weather-showers",           "weather-showers",          False, "Freezing drizzle"),
        '9' : ("weather-showers",           "weather-showers",          False, "Drizzle"),
        '10': ("weather-snow",              "weather-snow",             False, "Freezing rain"),
        '11': ("weather-showers",           "weather-showers",          False, "Showers"),
        '12': ("weather-showers",           "weather-showers",          False, "Showers"),
        '13': ("weather-snow",              "weather-snow",             False, "Snow flurries"),
        '14': ("weather-snow",              "weather-snow",             False, "Light snow showers"),
        '15': ("weather-snow",              "weather-snow",             False, "Blowing snow"),
        '16': ("weather-snow",              "weather-snow",             False, "Snow"),
        '17': ("weather-showers",           "weather-showers",          False, "Hail"),
        '18': ("weather-snow",              "weather-snow",             False, "Sleet"),
        '19': ("weather-fog",               "weather-fog",              False, "Dust"),
        '20': ("weather-fog",               "weather-fog",              False, "Foggy"),
        '21': ("weather-fog",               "weather-fog",              False, "Haze"),
        '22': ("weather-fog",               "weather-fog",              False, "Smoky"),
        '23': ("weather-clear",             "weather-clear-night",      False, "Blustery"),
        '24': ("weather-clear",             "weather-clear-night",      False, "Windy"),
        '25': ("weather-clear",             "weather-clear-night",      False, "Cold"),
        '26': ("weather-clouds",            "weather-clouds-night",     False, "Cloudy"),
        '27': ("weather-clouds",            "weather-clouds-night",     False, "Mostly cloudy"),
        '28': ("weather-clouds",            "weather-clouds-night",     False, "Mostly cloudy"),
        '29': ("weather-few-clouds",        "weather-few-clouds-night", False, "Partly cloudy"),
        '30': ("weather-few-clouds",        "weather-few-clouds-night", False, "Partly cloudy"),
        '31': ("weather-clear",             "weather-clear-night",      False, "Clear"),
        '32': ("weather-clear",             "weather-clear-night",      False, "Sunny"),
        '33': ("weather-clear",             "weather-clear-night",      False, "Fair"),
        '34': ("weather-clear",               "weather-clear-night",      False, "Fair"),
        '35': ("weather-showers-scattered",   "weather-showers-scattered",False, "Mixed rain and hail"),
        '36': ("weather-clear",               "weather-clear-night",      False, "Hot"),
        '37': ("weather-storm",               "weather-storm",            True,  "Isolated thunderstorms"),
        '38': ("weather-storm",               "weather-storm",            True,  "Scattered thunderstorms"),
        '39': ("weather-storm",               "weather-storm",            True,  "Scattered thunderstorms"),
        '40': ("weather-showers-scattered",   "weather-showers-scattered",False, "Scattered showers"),
        '41': ("weather-snow",                "weather-snow",             False, "Heavy snow"),
        '42': ("weather-snow",                "weather-snow",             False, "Scattered snow showers"),
        '43': ("weather-snow",                "weather-snow",             False, "Heavy snow"),
        '44': ("weather-few-clouds",          "weather-few-clouds-night", False, "Partly cloudy"),
        '45': ("weather-storm",               "weather-storm",            True,  "Thundershowers"),
        '46': ("weather-snow",                "weather-snow",             False, "Snow showers"),
        '47': ("weather-storm",               "weather-storm",            True,  "Isolated thundershowers"),
    }

    # Available conditions by Weather.com condition code; same as Yahoo
    _WeathercomConditions = _YahooConditions

    _OpenWeatherMapConditions = {
        '01d' : ("weather-clear",             "weather-clear",            True,  "sky is clear"),
        '01n' : ("weather-clear-night",       "weather-clear-night",      True,  "sky is clear"),
        '02d' : ("weather-few-clouds",        "weather-few-clouds",       True,  "few clouds"),
        '02n' : ("weather-few-clouds-night",  "weather-few-clouds-night", True,  "few clouds"),
        '03d' : ("weather-clouds",            "weather-clouds",           True,  "scattered clouds"),
        '03n' : ("weather-clouds-night",      "weather-clouds-night",     True,  "scattered clouds"),
        '04d' : ("weather-clouds",            "weather-clouds",           True,  "broken clouds"),
        '04n' : ("weather-clouds-night",      "weather-clouds-night",     True,  "broken clouds"),
        '09d' : ("weather-showers",           "weather-showers",          True,  "shower rain"),
        '09n' : ("weather-showers",           "weather-showers",          True,  "shower rain"),
        '10d' : ("weather-showers-scattered", "weather-showers-scattered",True,  "Rain"),
        '10n' : ("weather-showers-scattered", "weather-showers-scattered",True,  "Rain"),
        '11d' : ("weather-storm",             "weather-storm",            True,  "Thunderstorm"),
        '11n' : ("weather-storm",             "weather-storm",            True,  "Thunderstorm"),
        '13d' : ("weather-snow",              "weather-snow",             True,  "snow"),
        '13n' : ("weather-snow",              "weather-snow",             True,  "snow"),
        '50d' : ("weather-fog",               "weather-fog",              True,  "mist"),
        '50n' : ("weather-fog",               "weather-fog",              True,  "mist"),
    }

    def __init__(self):
        return

    # 「天候icon番号」から、「Gnome Icon名」を得る関数
    # 引数 :  code = (str)天候icon番号, flag_night = 夜用のicon名を得る場合はTrue
    def get_icon_name(self, code, flag_night):
        if WEB_SERVICE == 'WEATHER.COM' or WEB_SERVICE == 'YAHOO.COM':
            if flag_night == True:
                return self._WeathercomConditions[code][1]
            else:
                return self._WeathercomConditions[code][0]
        else:
            return self._OpenWeatherMapConditions[code][0]

if __name__ == "__main__":
    indicator = WeatherIndicator()
    indicator.main()
