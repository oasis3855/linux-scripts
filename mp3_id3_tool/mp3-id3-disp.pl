#!/usr/bin/perl

# ******************************************************
# Software name :display ID3v1/ID3v2 tag data (ID3v1/ID3v2タグの内容を簡易表示する)
# mp3-id3-disp.pl
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


# スクリプト自身・実行環境の文字コード設定
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
    
my $filename;       # mp3ファイル名
my @filearray = (); # ディレクトリが指定された場合、ファイル名が配列に格納される
# ID3v1/ID3v2 のどちらかのみのタグ情報を表示対象にする場合 1 をセット
my $flag_only_id3v1 = 0;
my $flag_only_id3v2 = 0;

# プログラム引数のオプションスイッチを読み込む
GetOptions('id3v1' => \ $flag_only_id3v1,
            'id3v2' => \ $flag_only_id3v2);

if($flag_only_id3v1 && $flag_only_id3v2){
    die("-id3v1 スイッチと -id3v2 スイッチはどちらか1個しか指定できません\n");
}

# プログラム引数を読み込んで、ファイル名とする
if($#ARGV >= 0 && length($ARGV[0])>1){
    $filename = $ARGV[0];
}
else{
    print("\nmp3 ID3v1/ID3v2 タグの簡易表示\n".
        basename($0)." (-id3v1|-id3v2) [mp3 filename|directory]\n\n".
        " -id3v1 : ID3v1 タグのみを表示\n".
        " -id3v2 : ID3v2 タグのみを表示\n");
    exit;
}

# 処理対象mp3ファイル一覧を@filearray配列に格納する
if(-d $filename){
    # プログラム引数がディレクトリだった場合、ファイルを検索
    if($filename =~ m/\/$/){ $filename .= '*.mp3'; }
    else{ $filename .= '/*.mp3'; }
    @filearray = File::Glob::glob($filename);

    print("ディレクトリ内に ".($#filearray+1)." 個のファイルが見つかりました\n");
}
else{
    # プログラム引数がファイル名だった場合
    push(@filearray, $filename);
}

foreach my $filename (@filearray){
    my $filename_base = sub_conv_to_flagged_utf8(basename($filename));    # 画面表示用ファイル名
    # ファイルが存在するか、読み込めるかの検査
    if(! -f $filename){
        print("E: file not exist, $filename_base\n");
        next;
    }
    if(! -r $filename){
        print("E: file not readable, $filename_base\n");
        next;
    }

    eval{
        my $mp3 = MP3::Tag->new($filename) or die("E: id3 header open error : $filename_base\n");

        $mp3->get_tags() or die("E: id3 header read error : $filename_base\n");

        print($filename_base."\n");

        # ID3v1 タグが見つかった場合、内容を表示する
        if (exists $mp3->{ID3v1} && !$flag_only_id3v2){
            my $id3v1 = $mp3->{ID3v1};
            print("  ID3v1 tag detect\n".
                "    artist : ".(defined($id3v1->artist)?sub_conv_to_flagged_utf8($id3v1->artist):'')."\n".
                "    title : ".(defined($id3v1->title)?sub_conv_to_flagged_utf8($id3v1->title):'')."\n".
                "    album : ".(defined($id3v1->album)?sub_conv_to_flagged_utf8($id3v1->album):'')."\n".
                "    year : ".(defined($id3v1->year)?$id3v1->year:'')."\n".
                "    track no : ".(defined($id3v1->track)?$id3v1->track:'')."\n".
                "    genre : ".(defined($id3v1->genre)?sub_conv_to_flagged_utf8($id3v1->genre):'')."\n".
                "    comment : ".(defined($id3v1->comment)?sub_conv_to_flagged_utf8($id3v1->comment):'')."\n");
        }

        # ID3v2 タグが見つかった場合、内容を表示する
        if (exists $mp3->{ID3v2} && !$flag_only_id3v1){
            my $id3v2 = $mp3->{ID3v2};
#my $ver = $id3v2->VERSION;
#my $enc_types = $id3v2->enc_types;
#$$id3v2->enc_types = qw( iso-8859-1 UTF-16LE UTF-16BE utf8 );
            # ID3v2タグより値を読み込んで、一旦変数に格納する
            my $title = $id3v2->get_frame('TIT2');
            my $artist = $id3v2->get_frame('TPE1');
            my $album = $id3v2->get_frame('TALB');
            my $year = $id3v2->get_frame('TYER');
            my $track = $id3v2->get_frame('TRCK');
            my $genre = $id3v2->get_frame('TCON');
            my $comment_hash = $id3v2->get_frame('COMM');
            my $comment = undef;
            if (defined($comment_hash)){
                my %comments = %{$comment_hash};
                $comment = $comments{'Text'};
            }
            my $copyright = $id3v2->get_frame('TCOP');
            my $diskno = $id3v2->get_frame('TPOS');
            # フレームの総数
            my $frameIDs = $id3v2->get_frame_ids;   # 全フレームの列挙（ハッシュ）
            my $frame_count = scalar(keys %$frameIDs);
            # 画面表示
            print("  ID3v2 (2.".$id3v2->version().") tag detect (".$frame_count." frames exist)\n".
                    "    artist : ".(defined($artist)?sub_conv_to_flagged_utf8($artist):'')."\n".
                    "    title : ".(defined($title)?sub_conv_to_flagged_utf8($title):'')."\n".
                    "    album : ".(defined($album)?sub_conv_to_flagged_utf8($album):'')."\n".
                    "    year : ".(defined($year)?$year:'')."\n".
                    "    track no : ".(defined($track)?$track:'')."\n".
                    "    genre : ".(defined($genre)?sub_conv_to_flagged_utf8($genre):'')."\n".
                    "    comment : ".(defined($comment)?sub_conv_to_flagged_utf8($comment):'')."\n".
                    "    copyright : ".(defined($copyright)?sub_conv_to_flagged_utf8($copyright):'')."\n".
                    "    disk no : ".(defined($diskno)?sub_conv_to_flagged_utf8($diskno):'')."\n"
                    );
        }
        $mp3->close();
    };
    if($@){
        # エラー検知したら、エラー文字列を表示し、次のファイル処理へ
        print($@);
        next;
    }
}


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


