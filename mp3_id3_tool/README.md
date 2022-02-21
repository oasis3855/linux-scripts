## mp3 ID3タグ読込・書込ツール(Perlスクリプト)<br />mp3 ID3 tag read/write tool<!-- omit in toc -->

[Home](https://oasis3855.github.io/webpage/) > [Software](https://oasis3855.github.io/webpage/software/index.html) > [Software Download](https://oasis3855.github.io/webpage/software/software-download.html) > [linux-scripts](../README.md) > ***mp3-id3-tool*** (this page)

<br />
<br />

Last Updated : Mar. 2012

- [ソフトウエアのダウンロード](#ソフトウエアのダウンロード)
- [概要](#概要)
- [動作確認](#動作確認)
  - [対象OS,依存ソフト等](#対象os依存ソフト等)
- [UTF-16LE + BOM での書込みについて](#utf-16le--bom-での書込みについて)
- [バージョン情報](#バージョン情報)
- [ライセンス](#ライセンス)

<br />
<br />

## ソフトウエアのダウンロード

- ![download icon](../readme_pics/soft-ico-download-darkmode.gif)  [このGitHubリポジトリを参照する（ソースコード）](../mp3_id3_tool/)

## 概要

MP3::Tagライブラリを用いて、mp3ファイルのID3v1/ID3v2タグの読み書きなどを行うコマンドラインツール。多数のファイルの一括処理を行うときに、ここで配布しているスクリプトをカスタマイズして使うためのテンプレート的な利用法を想定している

**このツールで出来ること**

-  指定したディレクトリ内の全てのmp3ファイル、または指定した1つのmp3ファイルを処理対象に出来る
-  ID3v1, ID3v2タグの内容をそれぞれ表示、属性値（フレーム値）を個別に書込み・消去することが出来る
-  Microsoft Windows Media Playerのバグ仕様に対応したUTF-16LE+BOMエンコードで書きこむことが出来る 

## 動作確認

-  Ubuntu Linux 10.04, 11.10 (Perl実行環境）
-  Rhythmbox, Totem, MP3 Diags（Ubuntu Linux）でのID3タグ表示
-  Windows Media Player（Windows 2000,XP,7）でのID3タグ表示 

### 対象OS,依存ソフト等

-  Linux/BSD（WindowsでもPerl実行環境が有れば可） 

## UTF-16LE + BOM での書込みについて

Microsoft Windows Media Playerのバグ仕様では、ID3v2標準仕様のUTF-16エンコード書き込みしたものは受け付けない。UTF-16LE + BOMエンコードで書きこむ必要がある。MP3::Tag::ID3v2のソースコードによれば

```Perl
# 0 = latin1 (effectively: unknown)
# 1 = UTF-16 with BOM	(we always write UTF-16le to cowtow to M$'s bugs)
# 2 = UTF-16be, no BOM
# 3 = UTF-8
my @dec_types = qw( iso-8859-1 UTF-16   UTF-16BE utf8 );
my @enc_types = qw( iso-8859-1 UTF-16LE UTF-16BE utf8 );
my @tail_rex;
 
# Actually, disable this code: it always triggers unsync...
my $use_utf16le = $ENV{MP3TAG_USE_UTF_16LE};
@enc_types = @dec_types unless $use_utf16le;
```

となっており、スクリプトを実行するシェルの環境変数にMP3TAG_USE_UTF_16LEが設定されていればよい。この状態で ```_add_frame``` サブルーチンで UTF-16LE + BOM付きで書き込まれる。

```Perl
if ($fs->{encoded}) {
    if ($encoding) {
        # 0 = latin1 (effectively: unknown)
        # 1 = UTF-16 with BOM (we write UTF-16le to cowtow to M$'s bugs)
        # 2 = UTF-16be, no BOM
        # 3 = UTF-8
        require Encode;
        if ($calc_enc or $encode_utf8) {    # e_u8==1 by default
            $d = Encode::encode($enc_types[$encoding], $d);
        } elsif ($encoding < 3) {
            # Reencode from UTF-8
            $d = Encode::decode('UTF-8', $d);
            $d = Encode::encode($enc_types[$encoding], $d);
        }
        $d = "\xFF\xFE$d" if $use_utf16le and $encoding == 1;
    } elsif (not $self->{fixed_encoding}  # Now $encoding == 0...
        and $self->get_config1('id3v2_fix_encoding_on_edit')
        and $e = $self->botched_encoding()
        and do { require Encode; Encode::decode($e, $d) ne $d }) {
        # If the current string is interpreted differently
        # with botched_encoding, need to unbotch...
        $self->fix_frames_encoding();
    }
}
$datastring .= $d;
```

ちなみに、このソースコードでもうひとつ分かるのは、```add_frame```に渡す文字列は```Encode::decode```で一旦utf8にデコードされるはずだが…。```require Encode;```というライブラリの呼び出し記述で分かるとおり、日本語に特化した呼び出し方法を取っていないので日本語はうまくデコードできない。つまり、```add_frame```に渡す文字列は予めutf8にデコードしてから渡さなければいけない。 

## バージョン情報

- Version 0.1 (2012/Mar/20)

## ライセンス

このスクリプトは [GNU General Public License v3ライセンスで公開する](https://gpl.mhatta.org/gpl.ja.html) フリーソフトウエア

