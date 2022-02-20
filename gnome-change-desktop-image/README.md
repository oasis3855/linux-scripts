## Gnomeデスクトップ壁紙 スライドショー cron呼出スクリプト (Linux シェルスクリプト)<br />Gnome background image slideshow, shell script for cron<!-- omit in toc -->

[Home](https://oasis3855.github.io/webpage/) > [Software](https://oasis3855.github.io/webpage/software/index.html) > [Software Download](https://oasis3855.github.io/webpage/software/software-download.html) > [linux-scripts](../README.md) > ***gnome-change-desktop-image*** (this page)

<br />
<br />

Last Updated : Jan. 2020

- [ソフトウエアのダウンロード](#ソフトウエアのダウンロード)
- [概要](#概要)
- [cronに設定する方法](#cronに設定する方法)
- [動作確認](#動作確認)
- [バージョン情報](#バージョン情報)
- [ライセンス](#ライセンス)


<br />
<br />

## ソフトウエアのダウンロード

- [このGitHubリポジトリを参照する（ソースコード）](../gnome-change-desktop-image/)


## 概要

Gnomeデスクトップ壁紙を、指定したディレクトリ内の画像の中からランダムに選択した画像ファイルに切り替えるシェルスクリプト。

このスクリプトをcronより定期的に実行することで、壁紙スライドショーを実現できる

## cronに設定する方法

30分ごとに壁紙スライドショーを実現する場合、```crontab -e```を実行し次の1行を追加する

```Bash
*/30 * * * * /usr/local/bin/change-desktop-image.sh /home/USER/Pictures/Wallpapers 1> /dev/null 2>&1
```

## 動作確認

- Ubuntu 16.04
- Ubuntu 18.04

## バージョン情報

- Version 1.0 (2017/Nov/23)
- Version 1.1 (2020/Jan/11)
  - Ubuntu 18.04対応 （pgrep gnome-session でPIDが複数返される場合の処理）
  - エラー時syslog出力に画像ディレクトリ名、PID等を追加

## ライセンス

このスクリプトは [GNU General Public License v3ライセンスで公開する](https://gpl.mhatta.org/gpl.ja.html) フリーソフトウエア

