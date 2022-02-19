#!/usr/bin/perl

# ******************************************************
# Software name :mp3 ID3v1/ID3v2 tool (mp3 ID3タグ ツール)
# mp3-id3-tool.pl
# version 0.1 (2012/03/20)
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
#
# GNU GPL Free Software
#
# このプログラムはフリーソフトウェアです。あなたはこれを、フリーソフトウェア財
# 団によって発行された GNU 一般公衆利用許諾契約書(バージョン2か、希望によっては
# それ以降のバージョンのうちどれか)の定める条件の下で再頒布または改変することが
# できます。
#
# このプログラムは有用であることを願って頒布されますが、*全くの無保証* です。
# 商業可能性の保証や特定の目的への適合性は、言外に示されたものも含め全く存在し
# ません。詳しくはGNU 一般公衆利用許諾契約書をご覧ください。
#
# あなたはこのプログラムと共に、GNU 一般公衆利用許諾契約書の複製物を一部受け取
# ったはずです。もし受け取っていなければ、フリーソフトウェア財団まで請求してく
# ださい(宛先は the Free Software Foundation, Inc., 59 Temple Place, Suite 330
# , Boston, MA 02111-1307 USA)。
#
# http://www.opensource.jp/gpl/gpl.ja.html
# ******************************************************

use warnings;
use strict;
use utf8;
use Encode::Guess qw/euc-jp shiftjis iso-2022-jp/;      # 必要ないエンコードは削除すること
use Getopt::Long;
use File::Basename;
use File::Glob;
use MP3::Tag;

my $flag_os = 'linux';  # linux/windows
my $flag_charcode = 'utf8';             # utf8/shiftjis
# IOの文字コードを規定
if($flag_charcode eq 'utf8'){
        binmode(STDIN, ":utf8");
        binmode(STDOUT, ":utf8");
        binmode(STDERR, ":utf8");
}
if($flag_charcode eq 'shiftjis'){
        binmode(STDIN, "encoding(sjis)");
        binmode(STDOUT, "encoding(sjis)");
        binmode(STDERR, "encoding(sjis)");
}
    
my $filename;
my @filearray = ();
my $flag_ac_mode;
my $flag_ac_overwrite = 0;
my $flag_find_v1;
my $counter = 0;

# プログラム引数のオプションスイッチを読み込む
GetOptions('ac=i' => \ $flag_ac_mode,
            'ac-ovwr' => \ $flag_ac_overwrite,
            'find-v1' => \ $flag_find_v1,
            );

# プログラム引数を読み込んで、ファイル名とする
if($#ARGV >= 0 && length($ARGV[0])>1){
    $filename = $ARGV[0];
}
else{
    print("\nmp3 ID3v1/ID3v2 タグ ツール\n".
        basename($0)." (-ac=n -ac-ovwr) (-find-v1) [mp3 filename|directory]\n\n".
        " -ac=n : Album属性を自動作成する, 作成パターンは n で指定する\n".
        "         0 : album='Artist-Title'\n".
        "         1 : album='(single)Artist-Title'\n".
        "         2 : album='Year-Artist-Title'\n".
        "         3 : album='(single)Year-Artist-title'\n".
        "         4 : album='Artist'\n".
        "         5 : album='(single)Artist'\n".
        "         6 : album='Artist(single)'\n".
        " -ac-ovwr : -acモード時に、Album属性が存在しても上書きする\n".
        " -find-v1 : ID3v1タグを持つファイルを検索\n");
    exit;
}

# 処理対象mp3ファイル一覧を@filearray配列に格納する
if(-d $filename){
    # プログラム引数がディレクトリだった場合、ファイルを検索
    if($filename =~ m/\/$/){ $filename .= '*.mp3'; }
    else{ $filename .= '/*.mp3'; }
    @filearray = File::Glob::glob($filename);

    print("ディレクトリ内に ".($#filearray+1)." 個のファイルが見つかりました\n処理を続ける場合はなにかキーを押してください\n");
    <STDIN>;
}
else{
    # プログラム引数がファイル名だった場合
    push(@filearray, $filename);
}

foreach my $filename (@filearray){
    my $filename_base = sub_conv_to_flagged_utf8(basename($filename));    # 画面表示用ファイル名
    # ファイルが存在するか、書き込めるかの検査
    if(! -f $filename){
        print("E: file not exist, $filename_base\n");
        next;
    }
    if(! -r $filename){
        print("E: file not readable, $filename_base\n");
        next;
    }
    if(! -w $filename){
        print("E: file not writeable, $filename_base\n");
        next;
    }

    eval{
        my $mp3 = MP3::Tag->new($filename) or die("E: id3 header open error : $filename_base\n");

        $mp3->get_tags() or die("E: id3 header read error : $filename_base\n");

        if(defined($flag_ac_mode)){
            if (exists $mp3->{ID3v2}){
                my $id3v2 = $mp3->{ID3v2};
                # ID3よりタグを読み込む
                my $title = $id3v2->get_frame('TIT2');
                my $artist = $id3v2->get_frame('TPE1');
                my $album = $id3v2->get_frame('TALB');
                my $year = $id3v2->get_frame('TYER');

                # ID3のartistタグ又はtitleタグが存在していなければスキップ
                if(!defined($artist) || length($artist)<=0 || !defined($title) || length($title)<=0){
                    die("E: skip (empty artist or title), $filename_base\n");
                }
                # ID3のalbumタグがすでに存在する場合は、書き換えない
                if(!$flag_ac_overwrite && (defined($album) && length($album)>0)){
                    die("   skip, $filename_base\n");
                }

                # 新しく設定するID3のalbumタグ
                my $new_album = (defined($artist)?($artist.'-'):'') . $title;
                if($flag_ac_mode == 1){ $new_album = '(single)'.(defined($artist)?($artist.'-'):'') . $title; }
                if($flag_ac_mode == 2){ $new_album = (defined($year)?($year.'-'):'').(defined($artist)?($artist.'-'):'') . $title; }
                if($flag_ac_mode == 3){ $new_album = '(single)'.(defined($year)?($year.'-'):'').(defined($artist)?($artist.'-'):'') . $title; }
                if($flag_ac_mode == 4){ $new_album = (defined($artist)?($artist):''); }
                if($flag_ac_mode == 5){ $new_album = '(single)'.(defined($artist)?($artist):''); }
                if($flag_ac_mode == 6){ $new_album = (defined($artist)?($artist):'').'(single)'; }

                # すでに存在しているalbumタグと同じだったら、スキップ
                if(defined($album) && $new_album eq $album){
                    die(" : skip (same) : $filename_base\n");
                }

                # id3のalbumタグを書き込む
                $new_album = sub_conv_to_flagged_utf8($new_album);
                if(!defined($album)){ $id3v2->add_frame('TALB', $new_album); }
                else{ $id3v2->change_frame('TALB', $new_album); }
                # 結果をID3v2 タグに書きこむ
                $id3v2->write_tag() or die("E: tag write error, $filename_base\n");

                print("   write success, $filename_base".(defined($ENV{MP3TAG_USE_UTF_16LE})?" (UTF-16LE mode)":"")."\n");
                $counter++;

            }
            else{
                print("E: id3 tag not found, $filename_base\n");
            }
            $mp3->close();
        }
        elsif(defined($flag_find_v1)){
            if (exists $mp3->{ID3v1}){
                print("ID3v1 found : $filename_base\n");
            }
        }
    };
    if($@){
        # エラー検知したら、エラー文字列を表示し、次のファイル処理へ
        print($@);
        next;
    }
}

if(defined($flag_ac_mode)){ print("$counter 個のファイルを変更しました\n"); }


# 任意の文字コードの文字列を、UTF-8フラグ付きのUTF-8に変換する
sub sub_conv_to_flagged_utf8{
        my $str = shift;
        my $enc_force = undef;
        if(@_ >= 1){ $enc_force = shift; }              # デコーダの強制指定

        if(!defined($str) || $str eq ''){ return(''); }         # $strが存在しない場合
        if(Encode::is_utf8($str)){ return($str); }      # 既にflagged utf-8に変換済みの場合
       
        # デコーダが強制的に指定された場合
        if(defined($enc_force)){
                if(ref($enc_force)){
                        $str = $enc_force->decode($str);
                        return($str);
                }
                elsif($enc_force ne '')
                {
                        $str = Encode::decode($enc_force, $str);
                }
        }

        my $enc = Encode::Guess->guess($str);   # 文字列のエンコードの判定

        unless(ref($enc)){
                # エンコード形式が2個以上帰ってきた場合 （shiftjis or utf8）
                my @arr_encodes = split(/ /, $enc);
                if(grep(/^$flag_charcode/, @arr_encodes) >= 1){
                        # $flag_charcode と同じエンコードが検出されたら、それを優先する
                        $str = Encode::decode($flag_charcode, $str);
                }
                elsif(lc($arr_encodes[0]) eq 'shiftjis' || lc($arr_encodes[0]) eq 'euc-jp' ||
                        lc($arr_encodes[0]) eq 'utf8' || lc($arr_encodes[0]) eq 'us-ascii'){
                        # 最初の候補でデコードする
                        $str = Encode::decode($arr_encodes[0], $str);
                }
        }
        else{
                # UTF-8でUTF-8フラグが立っている時以外は、変換を行う
                unless(ref($enc) eq 'Encode::utf8' && utf8::is_utf8($str) == 1){
                        $str = $enc->decode($str);
                }
        }

        return($str);
}


# 任意の文字コードの文字列を、UTF-8フラグ無しのUTF-8に変換する
sub sub_conv_to_unflagged_utf8{
        my $str = shift;

        # いったん、フラグ付きのUTF-8に変換
        $str = sub_conv_to_flagged_utf8($str);

        return(Encode::encode('utf8', $str));
}


# UTF8から現在のOSの文字コードに変換する
sub sub_conv_to_local_charset{
        my $str = shift;

        # UTF8から、指定された（OSの）文字コードに変換する
        $str = Encode::encode($flag_charcode, $str);
       
        return($str);
}


