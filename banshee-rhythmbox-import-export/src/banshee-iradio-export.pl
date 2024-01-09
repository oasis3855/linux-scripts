#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : Banshee のネットラジオ リストをPLSにエクスポートする
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# banshee-iradio-export.pl
#
# Version 0.1 (2012/March/06)
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
use File::Basename;
use Encode::Guess qw/euc-jp shiftjis iso-2022-jp/;  # 必要ないエンコードは削除すること
use DBI; 

my $flag_debug = 0;     # 1:デバッグ用冗長出力ON, 0:冗長出力OFF

my $flag_os = 'linux';  # linux/windows
my $flag_charcode = 'utf8';     # utf8/shiftjis

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

sub_main();
exit;

sub sub_main{
    if($#ARGV < 0){
        print("\n".basename($0)." - Export Playlist (*.PLS) from Banshee\n\nusage : ".basename($0)." [output PLS fiename] [Banshee DB filename]\n");
    }
    my $str_output_filename = '';
    my $str_banshee_db_filename = '';
    my $str_dsn = "dbi:SQLite:dbname="; # SQLite DB

    sub_user_input(\$str_output_filename, \$str_banshee_db_filename);

    print("=====\n 出力ファイル: ".$str_output_filename."\n Banshee DBファイル: ".$str_banshee_db_filename."\n");

    my @arr_data = ();
    $str_dsn .= $str_banshee_db_filename;
    sub_read_from_db($str_dsn, \@arr_data);
    
    sub_write_to_pls($str_output_filename, \@arr_data);

    print("エクスポート完了\n");
}

sub sub_user_input {
    # 引数
    my $str_output_filename_ref = shift;
    my $str_banshee_db_filename_ref = shift;
    
    # 出力ファイルのユーザ入力・指定
    if($#ARGV >= 0 && length($ARGV[0])>1){
        $$str_output_filename_ref = sub_conv_to_flagged_utf8($ARGV[0]);
    }
    else{
        print("出力PLSファイル名 : ");
        $_ = <STDIN>;
        chomp();
        unless(length($_)<=0){ $$str_output_filename_ref = $_; }
        else{ die("abort : empty filename\n"); }
    }

    # Banshee DBファイルのユーザ入力・指定
    if($#ARGV >= 1 && length($ARGV[1])>1){
        $$str_banshee_db_filename_ref = sub_conv_to_flagged_utf8($ARGV[1]);
    }
    else{
        print("Banshee DBファイル名 [".$ENV{"HOME"}."/.config/banshee-1/banshee.db] : ");
        $_ = <STDIN>;
        chomp();
        unless(length($_)<=0){ $$str_banshee_db_filename_ref = $_; }
        else{ $$str_banshee_db_filename_ref = $ENV{"HOME"}.'/.config/banshee-1/banshee.db'; }
    }
    unless( -f $$str_banshee_db_filename_ref){ die("error : ファイルが存在しない\n"); }

    return;
}

# banshee DBからネットラジオ登録一覧を配列に読み込む
sub sub_read_from_db{
    # 引数
    my $dsn = shift;        # DSN
    my $ref_arr = shift;    # PLSデータを格納する二次配列（へのリファレンス）

    my $CoreTracks_Table = 'CoreTracks';

    my $PrimarySourceID = sub_get_db_primarysource_id($dsn);
    if($flag_debug){ print("PrimarySourceID = ".$PrimarySourceID."\n"); }
    if($PrimarySourceID <= 0){ return; }

    print("Databaseから読み出し中 ...\n");

    my $dbh = undef;
    eval{
        # SQLサーバに接続
        $dbh = DBI->connect($dsn, "", "", {PrintError => 0, AutoCommit => 1}) or die(DBI::errstr);

        # TABLEが存在するかクエリを行う
        my $str_sql = "select count(*) from sqlite_master where type='table' and name='$CoreTracks_Table'";
        my $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        my @arr = $sth->fetchrow_array();
        $sth->finish();
        if($arr[0] != 1){
            if($flag_debug){ print("$CoreTracks_Table TABLE check : NOT exist\n"); }
            # CoreTracks が無い場合は coretracks で試す
            @arr = ();
            $CoreTracks_Table = 'coretracks';
            my $str_sql = "select count(*) from sqlite_master where type='table' and name='$CoreTracks_Table'";
            my $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
            $sth->execute() or die(DBI::errstr);
            my @arr = $sth->fetchrow_array();
            $sth->finish();
            if($arr[0] != 1){
                die("DatabaseにCoreTracksテーブルが見つからない\n");
            }
        }
        if($flag_debug){ print("$CoreTracks_Table TABLE check : exist\n"); }
        @arr = ();

        # データを読み出す
        my $n_added_count = 0;
        $str_sql = "SELECT Title,TitleLowered,Uri FROM $CoreTracks_Table WHERE PrimarySourceID = '$PrimarySourceID'";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        while(@arr = $sth->fetchrow_array()){
            push(@$ref_arr, [ @arr ]);
            if($flag_debug){ printf("%s(%s):%s\n",(defined($arr[0]) ? $arr[0] : '--'), (defined($arr[1]) ? $arr[1] : '--'), (defined($arr[2]) ? $arr[2] : '--')); }
        }
        $sth->finish();

        # DBを閉じる
        $dbh->disconnect() or die(DBI::errstr);
    };
    if($@){
            # evalによるDBエラートラップ：エラー時の処理
            if(defined($dbh)){ $dbh->disconnect(); }
            my $str = $@;
            chomp($str);
            print("SQLエラー: ".$str."\n");
    }

    return;
}


sub sub_write_to_pls {
    # 引数
    my $str_output_filename = shift;
    my $ref_arr = shift;    # PLSデータを格納する二次配列（へのリファレンス）

    my $Entries = @$ref_arr;
    print("要素数=".@$ref_arr."\n");

    eval{
        open(FH, '>'.$str_output_filename) or die;
        binmode(FH, ":utf8");
        print(FH "[playlist]\n".
                "numberofentries=".$Entries."\n\n") or die;
        my $i=1;
        foreach my $arr (@$ref_arr){
            if(defined($arr->[0]) && length($arr->[0])>0){ printf(FH "Title%d=%s\n",$i,sub_conv_to_flagged_utf8($arr->[0])) or die; }
            elsif(defined($arr->[1]) && length($arr->[1])>0){ printf(FH "Title%d=%s\n",$i,sub_conv_to_flagged_utf8($arr->[1])) or die; }
            else{ print("WARNING: no title station found, skipped\n");next; }
            printf(FH "File%d=%s\n",$i,defined($arr->[2])?sub_conv_to_flagged_utf8($arr->[2]):'') or die;
            printf(FH "Length%d=-1\n\n",$i) or die;
            $i++;
        }
        print(FH "Version=2\n") or die;
        close(FH);
    };
    if($@){
    }
}


# CorePrimarySource テーブルから "InternetRadioSource" のID番号を得る
sub sub_get_db_primarysource_id {
    # 引数
    my $dsn = shift;        # DSN

    my $CorePrimarySources_Table = 'CorePrimarySources';
    my $ret_id = -1;        # "InternetRadioSource" のID番号
    my $dbh = undef;
    eval{
        # SQLサーバに接続
        $dbh = DBI->connect($dsn, "", "", {PrintError => 0, AutoCommit => 1}) or die(DBI::errstr);


        # TABLEが存在するかクエリを行う
        my $str_sql = "select count(*) from sqlite_master where type='table' and name='$CorePrimarySources_Table'";
        my $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        my @arr = $sth->fetchrow_array();
        $sth->finish();
        
        if($arr[0] != 1){
            if($flag_debug){ print("$CorePrimarySources_Table TABLE check : NOT exist\n"); }
            # CorePrimarySources が無い場合は coreprimarysources で試す
            @arr = ();
            $CorePrimarySources_Table = 'coreprimarysources';
            my $str_sql = "select count(*) from sqlite_master where type='table' and name='$CorePrimarySources_Table'";
            my $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
            $sth->execute() or die(DBI::errstr);
            my @arr = $sth->fetchrow_array();
            $sth->finish();
            if($arr[0] != 1){
                die("DatabaseにCorePrimarySourcesテーブルが見つからない\n");
            }
        }
       if($flag_debug){ print("$CorePrimarySources_Table TABLE check : exist\n"); }
        @arr = ();

        # データを追加する
        my $n_added_count = 0;
        $str_sql = "SELECT PrimarySourceID FROM $CorePrimarySources_Table WHERE StringID LIKE '%InternetRadioSource%'";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        @arr = $sth->fetchrow_array();
        $sth->finish();
        if(!exists($arr[0]) || $arr[0] <= 0){ die("CorePrimarySources TABLE異常"); }
        $ret_id = $arr[0];
        # DBを閉じる
        $dbh->disconnect() or die(DBI::errstr);
    };
    if($@){
            # evalによるDBエラートラップ：エラー時の処理
            if(defined($dbh)){ $dbh->disconnect(); }
            my $str = $@;
            chomp($str);
            print("SQLエラー: ".$str."\n");
            $ret_id = -1;     # エラーの場合は -1 を返す
    }
    return($ret_id);
}


###########################################
# 共通関数からインポート

# 任意の文字コードの文字列を、UTF-8フラグ付きのUTF-8に変換する
sub sub_conv_to_flagged_utf8{
    my $str = shift;
    my $enc_force = undef;
    if(@_ >= 1){ $enc_force = shift; }      # デコーダの強制指定
   
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


# 引数で与えられたファイルの エンコードオブジェクト Encode::encode を返す
sub sub_get_encode_of_file{
    my $fname = shift;      # 解析するファイル名

    # ファイルを一気に読み込む
    open(FH, "<".sub_conv_to_local_charset($fname));
    my @arr = <FH>;
    close(FH);
    my $str = join('', @arr);       # 配列を結合して、一つの文字列に

    my $enc = Encode::Guess->guess($str);   # 文字列のエンコードの判定

    # エンコード形式の表示（デバッグ用）
    print("Automatick encode ");
    if(ref($enc) eq 'Encode::utf8'){ print("detect : utf8\n"); }
    elsif(ref($enc) eq 'Encode::Unicode'){
        print("detect : ".$$enc{'Name'}."\n");
    }
    elsif(ref($enc) eq 'Encode::XS'){
        print("detect : ".$enc->mime_name()."\n");
    }
    elsif(ref($enc) eq 'Encode::JP::JIS7'){
        print("detect : ".$$enc{'Name'}."\n");
    }
    else{
        # 二つ以上のエンコードが推定される場合は、$encに文字列が返る
        print("unknown (".$enc.")\n");
    }

    # エンコード形式が2個以上帰ってきた場合 （例：shiftjis or utf8）でテクと失敗と扱う
    unless(ref($enc)){
        $enc = '';
    }

    # ファイルがHTMLの場合 Content-Type から判定する
    if(lc($fname) =~ m/html$/ || lc($fname) =~ m/htm$/){
        my $parser = HTML::HeadParser->new();
        unless($parser->parse($str)){
            my $content_enc = $parser->header('content-type');
            if(defined($content_enc) && $content_enc ne '' && lc($content_enc) =~ m/text\/html/ ){
                if(lc($content_enc) =~ m/utf-8/){ $enc = 'utf8'; }
                elsif(lc($content_enc) =~ m/shift_jis/){ $enc = 'shiftjis'; }
                elsif(lc($content_enc) =~ m/euc-jp/){ $enc = 'euc-jp'; }
               
                print("HTML Content-Type detect : ". $content_enc ." (is overrided)\n");
                $enc = $content_enc;
            }
        }
    }

    return($enc);
}
  
