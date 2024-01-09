## Banshee/Rhythmboxのインターネットラジオ一覧をインポート/エクスポートするPerlスクリプト (Linux)<!-- omit in toc -->

[Home](https://oasis3855.github.io/webpage/) > [Software](https://oasis3855.github.io/webpage/software/index.html) > [Software Download](https://oasis3855.github.io/webpage/software/software-download.html) > [linux-scripts](../README.md) > ***banshee-rhythmbox-import-export*** (this page)

<br />
<br />

Last Updated : Mar. 2012

- [ソフトウエアのダウンロード](#ソフトウエアのダウンロード)
- [概要](#概要)
- [Rhythmbox 用のスクリプトについて](#rhythmbox-用のスクリプトについて)
  - [rhythmbox-iradio-import.pl](#rhythmbox-iradio-importpl)
  - [rhythmbox-iradio-export.pl](#rhythmbox-iradio-exportpl)
  - [Rhythmboxのデータファイル rhythmdb.xml 形式の例](#rhythmboxのデータファイル-rhythmdbxml-形式の例)
  - [Rhythmboxに新規インターネットラジオ曲URLを登録する方法](#rhythmboxに新規インターネットラジオ曲urlを登録する方法)
  - [エラー、バグ回避方法](#エラーバグ回避方法)
- [Banshee 用のスクリプトについて](#banshee-用のスクリプトについて)
  - [banshee-iradio-export.pl](#banshee-iradio-exportpl)
  - [banshee-iradio-import.pl](#banshee-iradio-importpl)
- [動作確認](#動作確認)
- [バージョン情報](#バージョン情報)
- [ライセンス](#ライセンス)

<br />
<br />

## ソフトウエアのダウンロード

- ![download icon](../readme_pics/soft-ico-download-darkmode.gif)  [このGitHubリポジトリを参照する（ソースコード）](../banshee-rhythmbox-import-export/src)

<br />
<br />

## 概要

Ubuntuの標準メディアプレーヤのBansheeとRhythmboxで、インターネットラジオ一覧のインポート／エクスポートが出来無い。他のマシンに設定を移行するためにも、インポート／エクスポート機能を実現すべきということで、間に合わせのスクリプトを作ってみた。

なお、ここに掲載しているPerlスクリプトは私の環境で動く程度の動作状況していないため、エラー発生する可能性があることを十分承知してください。 

## Rhythmbox 用のスクリプトについて

このスクリプトでインポート／エクスポートするプレイリストファイル（PLS形式）は、次のようなものである。

```PLS
Title1=WSUM 91.7 FM (University of Wisconsin)
File1=http://stream.studio.wsum.wisc.edu/wsum128
Length1=-1

Title2=WUVT-FM 90.7 (Virginia Tech)
File2=https://stream.wuvt.vt.edu/wuvt.ogg
Length2=-1
```

### rhythmbox-iradio-import.pl

任意のプレイリストファイル（PLS形式）をRhythmboxのインターネットラジオ一覧（~/.local/share/rhythmbox/rhythmdb.xml）にインポートするスクリプト。

### rhythmbox-iradio-export.pl

Rhythmboxのインターネットラジオ一覧（~/.local/share/rhythmbox/rhythmdb.xml）から、type=iradioのものをプレイリストファイル（PLS形式）フォーマットのテキストとして標準出力に書き出します。パイプ出力でプレイリストファイルに書きこむこともできます。

```bash
perl ./rhythmbox-iradio-export.pl > example.pls
```

### Rhythmboxのデータファイル rhythmdb.xml 形式の例

```xml
<?xml version="1.0" standalone="yes"?>
<rhythmdb version="2.0">
  <entry type="iradio">
    <title>WSUM 91.7 FM (University of Wisconsin)</title>
    <genre>College Radio</genre>
    <artist></artist>
    <album></album>
    <location>http://stream.studio.wsum.wisc.edu/wsum128</location>
    <date>0</date>
    <media-type>application/octet-stream</media-type>
  </entry>
  <entry type="iradio">
    <title>WUVT-FM 90.7 (Virginia Tech)</title>
    <genre>College Radio</genre>
    <artist></artist>
    <album></album>
    <location>https://stream.wuvt.vt.edu/wuvt.ogg</location>
    <date>0</date>
    <media-type>application/octet-stream</media-type>
  </entry>
〜以下省略〜
```

### Rhythmboxに新規インターネットラジオ曲URLを登録する方法

Ubuntu 22.04のRhythmboxには、新規登録ボタンが見つからなかったので、次のような回避方法を取ることで新規のインターネットラジオ局URLが登録できた。

まず最初に、メインウインドウの左側ペイン「ライブラリ」にある「ラジオ」を選択し、次のようなm3u形式のダミーファイルをドラッグ＆ドロップすると、エントリーが1つ追加される。

```m3u
# Radio Swiss Pop
https://stream.srg-ssr.ch/m/rsp/mp3_128
```

新規登録されたエントリーを右クリックし、プロパティを編集すれば新規インターネットラジオ局（URL）の登録が完了する。

### エラー、バグ回避方法

- rhythmbox-iradio-import.plでのインポート時エラー 

  - プレイリストに何も登録されていない状態ではエラーとなる（rhythmdb.xmlが存在しない場合と、rhythmdb.xmlのentry数が2未満のとき）。適当なmp3ファイルをプレイリストに2個以上登録してからこのスクリプトを実行する。 

- "could not find ParserDetails.ini"が出力される 

  - XML::Simpleライブラリの内部で参照されているParserDetails.iniが存在しない。ルート権限で``` perl -MXML::SAX -e "XML::SAX->add_parser(q(XML::SAX::PurePerl))->save_parsers()" ```を実行してParserDetails.iniを作成する。 

<br />
<br />

## Banshee 用のスクリプトについて

Ubuntu 10.10より標準メディアプレーヤになった。Playlistのインポート対応していないが、不完全な形でエクスポートには対応している。

### banshee-iradio-export.pl

Bansheeの設定ファイルはSQLite形式で~/.config/banshee-1/banshee.dbに保存されている。CorePrimarySourcesテーブルで``` StringID=InternetRadioSource-internet-radio``` の``` PrimarySourceID ```を取得し、``` CoreTracks ```テーブルより``` PrimarySourceID ```が一致する行をPlaylistに出力するスクリプト。

### banshee-iradio-import.pl

``` CoreTracks ```テーブルにPlaylistを書き込むスクリプト。 

<br />
<br />

## 動作確認

- Ubuntu 10.04
- Ubuntu 11.10
- Ubuntu 22.04 (Rhythmboxのみ動作確認を行った)

<br />
<br />

## バージョン情報

- Version 0.1 (2012/03/06)

<br />
<br />

## ライセンス

このスクリプトは [GNU General Public License v3ライセンスで公開する](https://gpl.mhatta.org/gpl.ja.html) フリーソフトウエア

