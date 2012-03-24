#!/usr/bin/perl

# ******************************************************
# Software name :write ID3v1/ID3v2 tag data (ID3v1/ID3v2タグに書きこむ)
# mp3-id3-write.pl
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

my $flag_id3v1 = 0; # 書きこみ対象を ID3v1 タグとする（0の場合はID3v2タグに書きこむ）
# タグのフレームに書きこむ値
my $artist_new;
my $title_new;
my $album_new;
my $year_new;
my $track_new;
my $genre_new;
my $comment_new;
my $copyright_new;

# プログラム引数のオプションスイッチを読み込む
GetOptions('id3v1' => \ $flag_id3v1,
            'artist=s' => \ $artist_new,
            'title=s' => \ $title_new,
            'album=s' => \ $album_new,
            'year=i' => \ $year_new,
            'track=i' => \ $track_new,
            'genre=s' => \ $genre_new,
            'comment=s' => \ $comment_new,
            'copyright=s' => \ $copyright_new
            );

# プログラム引数を読み込んで、ファイル名とする
if($#ARGV >= 0 && length($ARGV[0])>1){
    $filename = $ARGV[0];
}
else{
    print("\nmp3 ID3v1/ID3v2 タグに書きこむ\n".
        basename($0)." (-id3v1) (-artist=string ... -title=string) [mp3 filename|directory]\n\n".
        " -id3v1 : ID3v1 タグに書きこむ（このスイッチを指定しない場合は ID3v2 タグに書きこむ）\n".
        " -artist=string : write artist (ID3v1の場合は 30 bytes)\n".
        " -title=string : write title (ID3v1の場合は 30 bytes)\n".
        " -album=string : write album (ID3v1の場合は 30 bytes)\n".
        " -year=number : write year\n".
        " -track=number : write track\n".
        " -genre=string|number : write genre (ID3v1の場合は ジャンルを示す数値)\n".
        " -comment=string : write comment (ID3v2のみ)\n".
        " -copyright=string : write copyright (ID3v2のみ)\n"
        );
    exit;
}

if(defined($year_new) && ($year_new !~ m/^\d+$/ || $year_new < 1900 || $year_new > 2032)){
    die("year が範囲外（1900以上2032以下であること）\n");
}
if(defined($track_new) && ($track_new !~ m/^\d+$/ || $track_new < 0 || $track_new > 1000)){
    die("track が範囲外（1000以下であること）\n");
}
if(defined($genre_new) && $flag_id3v1 && ($genre_new !~ m/^\d+$/ || $genre_new < 0 || $genre_new > 150)){
    die("genre が範囲外（ID3v1の場合、0から150までであること）\n");
}

# 処理対象mp3ファイル一覧を@filearray配列にる
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

        if($flag_id3v1){
            print("  write to ID3v1\n");
            # ID3v1 タグに書きこむ
            my $id3v1;
            if(exists($mp3->{ID3v1})){ $id3v1 = $mp3->{ID3v1}; }
            else{ $id3v1 = $mp3->new_tag("ID3v1"); }    # ID3v1タグ自体が存在しない場合は新規作成
            # タグのフレームに書き込み（文字コードはShiftJIS）
            if(defined($artist_new)){ $id3v1->artist(Encode::encode('shiftjis', sub_conv_to_flagged_utf8($artist_new))); print("    artist : ".sub_conv_to_flagged_utf8($artist_new)."\n"); }
            if(defined($title_new)){ $id3v1->title(Encode::encode('shiftjis', sub_conv_to_flagged_utf8($title_new))); print("    title : ".sub_conv_to_flagged_utf8($title_new)."\n"); }
            if(defined($album_new)){ $id3v1->album(Encode::encode('shiftjis', sub_conv_to_flagged_utf8($album_new))); print("    album : ".sub_conv_to_flagged_utf8($album_new)."\n"); }
            if(defined($year_new)){ $id3v1->year(Encode::encode('shiftjis', sub_conv_to_flagged_utf8($year_new))); print("    year : ".sub_conv_to_flagged_utf8($year_new)."\n"); }
            if(defined($track_new)){ $id3v1->track(Encode::encode('shiftjis', sub_conv_to_flagged_utf8($track_new))); print("    track : $track_new\n"); }
            if(defined($genre_new)){ $id3v1->genre(Encode::encode('shiftjis', sub_conv_to_flagged_utf8($genre_new))); print("    genre : $genre_new\n"); }
            $id3v1->write_tag();
        }
        else{
            print("  write to ID3v2".(defined($ENV{MP3TAG_USE_UTF_16LE})?" (UTF-16LE mode)":"")."\n");
            # ID3v2 タグに書きこむ
            my $id3v2;
            if(exists($mp3->{ID3v2})){ $id3v2 = $mp3->{ID3v2}; }
            else{ $id3v2 = $mp3->new_tag("ID3v2"); }
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

            # 書き込み時はutf8で文字列を渡すと、文字列の種類により自動的にLATINかUTF16に自動変換される。
            # 強制的に変換形式を指定するときは、$id3v2->add_frame('TIT2', $encoding, $title_new);
            #   $encoding = 0:latin, 1:utf16, 2:utf16be, 3:utf8
            
            # artistフレームに書き込む
            if(defined($artist_new)){
                $artist_new = sub_conv_to_flagged_utf8($artist_new);
                if(!defined($artist)){ $id3v2->add_frame('TPE1', $artist_new); }
                else{ $id3v2->change_frame('TPE1', $artist_new); }
                print("    artist : ".(defined($artist)?$artist:'')." -> $artist_new\n");
            }
            # titleフレームに書き込む
            if(defined($title_new)){
                $title_new = sub_conv_to_flagged_utf8($title_new);
                if(!defined($title)){ $id3v2->add_frame('TIT2', $title_new); }
                else{ $id3v2->change_frame('TIT2', $title_new); }
                print("    title : ".(defined($title)?$title:'')." -> $title_new\n");
            }
            # albumフレームに書き込む
            if(defined($album_new)){
                $album_new = sub_conv_to_flagged_utf8($album_new);
                if(!defined($album)){ $id3v2->add_frame('TALB', $album_new); }
                else{ $id3v2->change_frame('TALB', $album_new); }
                print("    album : ".(defined($album)?$album:'')." -> $album_new\n");
            }
            # yearフレームに書き込む
            if(defined($year_new)){
                $year_new = sub_conv_to_flagged_utf8($year_new);
                if(!defined($year)){ $id3v2->add_frame('TYER', $year_new); }
                else{ $id3v2->change_frame('TYER', $year_new); }
                print("    year : ".(defined($year)?$year:'')." -> $year_new\n");
            }
            # trackフレームに書き込む
            if(defined($track_new)){
                $track_new = sub_conv_to_flagged_utf8($track_new);
                if(!defined($track)){ $id3v2->add_frame('TRCK', $track_new); }
                else{ $id3v2->change_frame('TRCK', $track_new); }
                print("    track : ".(defined($track)?$track:'')." -> $track_new\n");
            }
            # genreフレームに書き込む
            if(defined($genre_new)){
                $genre_new = sub_conv_to_flagged_utf8($genre_new);
                if(!defined($genre)){ $id3v2->add_frame('TCON', $genre_new); }
                else{ $id3v2->change_frame('TCON', $genre_new); }
                print("    genre : ".(defined($genre)?$genre:'')." -> $genre_new\n");
            }
            # commentフレームに書き込む
            if(defined($comment_new)){
                $comment_new = sub_conv_to_flagged_utf8($comment_new);
                if(!defined($comment)){ $id3v2->add_frame('COMM', 'ENG', '', $comment_new); }
                else{ $id3v2->change_frame('COMM', 'ENG', '', $comment_new); }
                print("    comment : ".(defined($comment)?$comment:'')." -> $comment_new\n");
            }
            # copyrightフレームに書き込む
            if(defined($copyright_new)){
                $copyright_new = sub_conv_to_flagged_utf8($copyright_new);
                if(!defined($copyright)){ $id3v2->add_frame('TCOP', $copyright_new); }
                else{ $id3v2->change_frame('TCOP', $copyright_new); }
                print("    copyright : ".(defined($copyright)?$copyright:'')." -> $copyright_new\n");
            }
            # 結果をID3v2 タグに書きこむ
            $id3v2->write_tag() or die("E: tag write error, $filename_base\n");
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


{
    package MP3::Tag::ID3v2::UTF16LE;
    use base qw(MP3::Tag::ID3v2);

    my @dec_types = qw( iso-8859-1 UTF-16LE   UTF-16BE utf8 );

    sub new{
        my ($class, %param) = @_;
        my $self = MP3::Tag->new(%param);
        return bless $self, $class;
#        bless $self, $class;
#        return $self;
    }

    sub change_frame_utf16le {
        my ($self, $fname, @data) = @_;
        $self->get_frame_ids() unless exists $self->{frameIDs};
        return undef unless exists $self->{frames}->{$fname};
    
        $self->remove_frame($fname);
        $self->add_frame($fname, @data);
    
        return 1;
    }

}

