## 各種スクリプト類（Linux）<br />Linux tool scripts<!-- omit in toc -->

[Home](https://oasis3855.github.io/webpage/) > [Software](https://oasis3855.github.io/webpage/software/index.html) > [Software Download](https://oasis3855.github.io/webpage/software/software-download.html) > ***linux-scripts*** (this page)

<br />
<br />

- [住所録CSVファイル相互変換 (Linux, Perlスクリプト)](#住所録csvファイル相互変換-linux-perlスクリプト)
- [Gnomeデスクトップ壁紙 スライドショー cron呼出スクリプト (Linux シェルスクリプト)](#gnomeデスクトップ壁紙-スライドショー-cron呼出スクリプト-linux-シェルスクリプト)
- [Gnomeデスクトップ壁紙 スライドショー XML作成 (Linux Perlスクリプト)](#gnomeデスクトップ壁紙-スライドショー-xml作成-linux-perlスクリプト)
- [Gnome 2 ログオンテーマ](#gnome-2-ログオンテーマ)
- [Googleカレンダーの読み書きとiCalインポート](#googleカレンダーの読み書きとicalインポート)
- [GPX GPSログファイル 変換ツール類](#gpx-gpsログファイル-変換ツール類)
- [未読メール通知Gnomeインジケータ アプレット](#未読メール通知gnomeインジケータ-アプレット)
- [SMTPサーバを利用するテキストメール送信Perlスクリプト](#smtpサーバを利用するテキストメール送信perlスクリプト)
- [mp3 ID3タグ読込・書込ツール(Perlスクリプト)](#mp3-id3タグ読込書込ツールperlスクリプト)
- [Linux Nautilusのコンテキストメニュー「スクリプト」で使う小技スクリプト類](#linux-nautilusのコンテキストメニュースクリプトで使う小技スクリプト類)
- [天気・気温通知Gnomeインジケータ アプレット](#天気気温通知gnomeインジケータ-アプレット)

<br />
<br />

## 住所録CSVファイル相互変換 (Linux, Perlスクリプト)

Thunderbird、GMailの住所録（アドレス帳や連絡先とも呼ばれる）からエクスポートしたCSVファイルの形式を相互変換するためのスクリプト。変換ルールは、定義ファイルを作ることでユーザの使っている住所録管理ソフトにも対応することも出来ます

[配布ディレクトリ addressbook_converter](addressbook_converter/README.md) (2011/12/08)

<br />
<br />


## Gnomeデスクトップ壁紙 スライドショー cron呼出スクリプト (Linux シェルスクリプト)

Gnomeデスクトップ壁紙を、指定したディレクトリ内の画像の中からランダムに選択した画像ファイルに切り替えるシェルスクリプト。

このスクリプトをcronより定期的に実行することで、壁紙スライドショーを実現できる

[配布ディレクトリ gnome-change-desktop-image](gnome-change-desktop-image/README.md) (2020/01/11)

<br />
<br />

## Gnomeデスクトップ壁紙 スライドショー XML作成 (Linux Perlスクリプト)

Gnomeデスクトップ壁紙（画像）のスライドショー機能を使うためのXMLファイルを作成するPerlスクリプト

[配布ディレクトリ gnome-desktop-img-xmlmaker](gnome-desktop-img-xmlmaker/README.md)  (2011/04/20)

<br />
<br />

## Gnome 2 ログオンテーマ

Gnome 2 ログオンテーマで任意の画像を用いるサンプル例

[配布ディレクトリ gnome2_logon_theme](gnome2_logon_theme/README.md)  (2008/09/14)

<br />
<br />

## Googleカレンダーの読み書きとiCalインポート

Googleカレンダーから予定を読み出す／書き込むサンプル スクリプト。それぞれgtkダイアログを実装している

[配布ディレクトリ googlecalendar_readwrite](googlecalendar_readwrite/README.md)  (2014/03/14)

<br />
<br />

## GPX GPSログファイル 変換ツール類 

GPX形式のGPSログファイルを、CSVファイルやGoogle Maps Javascript API形式などに変換するためのスクリプト

[配布ディレクトリ gpx-tools](gpx-tools/README.md)  (2021/09/19)

<br />
<br />

## 未読メール通知Gnomeインジケータ アプレット

Ubuntu LinuxのGnomeパネルまたはUnityパネルの通知領域に常駐する、未読メール通知インジケータです。IMAP4メール サーバとの通信はSSLを用いています

[配布ディレクトリ imap4_mail_indicator](imap4_mail_indicator/README.md)  (2014/05/10)

<br />
<br />

## SMTPサーバを利用するテキストメール送信Perlスクリプト

```Net::SMTPS```ライブラリを用いたテキストメール送信スクリプト。事前に設定ファイルに格納したSMTPサーバの認証情報を利用し、任意の相手先にテキストメールを送信する

ここで配布しているスクリプトをカスタマイズして利用するためのテンプレート的な利用法を想定している

[配布ディレクトリ mail-textfile-send](mail-textfile-send/README.md)  (2019/09/23)

<br />
<br />

## mp3 ID3タグ読込・書込ツール(Perlスクリプト)

MP3::Tagライブラリを用いて、mp3ファイルのID3v1/ID3v2タグの読み書きなどを行うコマンドラインツール。多数のファイルの一括処理を行うときに、ここで配布しているスクリプトをカスタマイズして使うためのテンプレート的な利用法を想定している

[配布ディレクトリ mp3_id3_tool](mp3_id3_tool/README.md)  (2012/03/20)

<br />
<br />

## Linux Nautilusのコンテキストメニュー「スクリプト」で使う小技スクリプト類

Linux Nautilus（ファイル ブラウザ）のコンテキストメニュー「スクリプト」で参照されるディレクトリに、ここで配布するスクリプトを置いて、いわゆるWindows エクスプローラーでの「送る」でファイルを開く的なことを実現するための小技スクリプト類

[配布ディレクトリ nautilus-script](nautilus-script/README.md)  (2020/07/12)

<br />
<br />

## 天気・気温通知Gnomeインジケータ アプレット

Ubuntu LinuxのGnomeパネルまたはUnityパネルの通知領域に常駐する、天気・気温インジケータ

[配布ディレクトリ weather_indicator](weather_indicator/README.md)  (2014/05/17)
