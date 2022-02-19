#!/usr/bin/perl

# ******************************************************
# Software name :delete ID3v1/ID3v2 tag data (ID3v1/ID3v2タグ、またはその内容を削除する)
# mp3-id3-delete.pl
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

my $flag_id3v1 = 0;     # ID3v1 を処理対象にする
my $flag_id3v2 = 0;     # ID3v2 を処理対象にする
# 削除対象のタグ フレームを指定する
my $flag_delete_id3tag = 0;     # ID3タグ自体を削除する
my $flag_artist = 0;
my $flag_title = 0;
my $flag_album = 0;
my $flag_year = 0;
my $flag_track = 0;
my $flag_genre = 0;
my $flag_comment = 0;
my $flag_copyright = 0;
my $flag_diskno = 0;

# プログラム引数のオプションスイッチを読み込む
GetOptions('id3v1' => \ $flag_id3v1,
            'id3v2' => \ $flag_id3v2,
            'artist' => \ $flag_artist,
            'title' => \ $flag_title,
            'album' => \ $flag_album,
            'year' => \ $flag_year,
            'track' => \ $flag_track,
            'genre' => \ $flag_genre,
            'comment' => \ $flag_comment,
            'copyright' => \ $flag_copyright,
            'diskno' => \ $flag_diskno
            );

# プログラム引数を読み込んで、ファイル名とする
if($#ARGV >= 0 && length($ARGV[0])>1){
    $filename = $ARGV[0];
}
else{
    print("\nmp3 ID3v1/ID3v2 タグの削除\n".
        basename($0)." -id3v1 -id3v2 (-artist -title -album -year -track -genre -comment -copyright -diskno) [mp3 filename|directory]\n\n".
        " -id3v1 : ID3v1 タグを処理対象とする\n".
        " -id3v2 : ID3v2 タグを処理対象とする\n".
        " -artist ... -diskno : 処理対象のフレーム（値）。指定しないときはタグ自体を削除\n");
    exit;
}

if(!$flag_id3v1 && !$flag_id3v2){
    die("処理対象を決定する -id3v1 または -id3v2 スイッチのどちらかを指定する必要があります\n");
}

# ターゲットのフレームが指定されないときは、タグ自体を削除
if(!$flag_artist && !$flag_title && !$flag_album && !$flag_year && !$flag_track
    && !$flag_genre && !$flag_comment && !$flag_copyright && !$flag_diskno){
    $flag_delete_id3tag = 1;
    print("フレーム名が指定されなかったため、タグ自体を削除します\n");
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
        print("E: file not writable, $filename_base\n");
        next;
    }

    eval{
        my $mp3 = MP3::Tag->new($filename) or die("E: id3 header open error : $filename_base\n");

        $mp3->get_tags() or die("E: id3 header read error : $filename_base\n");

        print($filename_base."\n");

        # ID3v1 タグの削除
        if (exists $mp3->{ID3v1} && $flag_id3v1){
            my $id3v1 = $mp3->{ID3v1};
            print("  id3v1 tag detect\n");

            if($flag_delete_id3tag){
                # ID3v1 タグ自体を削除する
                $id3v1->remove_tag();
                print("  remove ALL ID3v1 tag\n");
            }
            else{
                # 指定されたタグの値を削除（長さゼロの文字列に書き換える）
                if($flag_artist && defined($id3v1->artist)){ $id3v1->artist(''); print("    artist removed\n"); }
                if($flag_title && defined($id3v1->title)){ $id3v1->title(''); print("    title removed\n"); }
                if($flag_album && defined($id3v1->album)){ $id3v1->album(''); print("    album removed\n"); }
                if($flag_year && defined($id3v1->year)){ $id3v1->year(''); print("    year removed\n"); }
                if($flag_track && defined($id3v1->track)){ $id3v1->track(''); print("    track removed\n"); }
                if($flag_genre && defined($id3v1->genre)){ $id3v1->genre(''); print("    genre removed\n"); }
                if($flag_comment && defined($id3v1->comment)){ $id3v1->comment(''); print("    comment removed\n"); }
                # 結果をID3v2 タグに書きこむ
                $id3v1->write_tag() or die("E: tag write error, $filename_base\n");
            }
        }

        # ID3v2 タグの削除
        if (exists $mp3->{ID3v2} && $flag_id3v2){

            my $id3v2 = $mp3->{ID3v2};
            print("  id3v2 (2.".$id3v2->version().") tag detect\n");

            if($flag_delete_id3tag){
                # ID3v2 タグ自体を削除する
                $id3v2->remove_tag();
                print("  remove ALL ID3v2 tag\n");
            }
            else{
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
                # タグの値が存在する場合、削除を行う
                if($flag_title && defined($title)){ $id3v2->remove_frame('TIT2'); print("    title removed\n"); }
                if($flag_artist && defined($artist)){ $id3v2->remove_frame('TPE1'); print("    artist removed\n"); }
                if($flag_album && defined($album)){ $id3v2->remove_frame('TALB'); print("    album removed\n"); }
                if($flag_year && defined($year)){ $id3v2->remove_frame('TYER'); print("    year removed\n"); }
                if($flag_track && defined($track)){ $id3v2->remove_frame('TRCK'); print("    track removed\n"); }
                if($flag_genre && defined($genre)){ $id3v2->remove_frame('TCON'); print("    genre removed\n"); }
                if($flag_comment && defined($comment)){ $id3v2->remove_frame('COMM'); print("    comment removed\n"); }
                if($flag_copyright && defined($copyright)){ $id3v2->remove_frame('TCOP'); print("    copyright removed\n"); }
                if($flag_diskno && defined($diskno)){ $id3v2->remove_frame('TPOS'); print("    diskno removed\n"); }

                my $frameIDs = $id3v2->get_frame_ids;   # 全フレームの列挙（ハッシュ）
                if(scalar(keys %$frameIDs) <= 0){
                    # フレームに何も残っていない場合は、ID3タグ自体を削除する
                    $id3v2->remove_tag();
                    print("    no frame remains, ID3v2 tag removed\n");
                }
                else{
                    # 結果をID3v2 タグに書きこむ
                    $id3v2->write_tag() or die("E: tag write error, $filename_base\n");
                }
            }
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


