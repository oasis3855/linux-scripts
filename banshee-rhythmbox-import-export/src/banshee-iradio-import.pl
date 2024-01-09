#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : Banshee にPLS形式のネットラジオ リストをインポートする
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# banshee-iradio-import.pl
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
        print("\n".basename($0)." - Import Playlist (*.PLS) into Banshee\n\nusage : ".basename($0)." [input PLS fiename] [Banshee DB filename]\n");
    }
    my $str_input_filename = '';
    my $str_banshee_db_filename = '';
    my $mode_delete_radio = 0;
    my $str_dsn = "dbi:SQLite:dbname="; # SQLite DB

    sub_user_input(\$str_input_filename, \$str_banshee_db_filename, \$mode_delete_radio);

    print("=====\n 入力ファイル: ".$str_input_filename."\n Banshee DBファイル: ".$str_banshee_db_filename."\n");

    my @arr_data = ();
    sub_read_from_pls($str_input_filename, \@arr_data);
    
    $str_dsn .= $str_banshee_db_filename;
    if($mode_delete_radio == 1){
        sub_delete_radio_from_db($str_dsn);
    }
    sub_add_to_db($str_dsn, \@arr_data);
    
    print("インポート完了\n");
}

# ファイル名等の対話的入力
sub sub_user_input {
    # 引数
    my $str_input_filename_ref = shift;
    my $str_banshee_db_filename_ref = shift;
    my $mode_delete_radio_ref = shift;
    
    # 入力ファイルのユーザ入力・指定
    if($#ARGV >= 0 && length($ARGV[0])>1){
        $$str_input_filename_ref = sub_conv_to_flagged_utf8($ARGV[0]);
    }
    else{
        print("入力PLSファイル名 : ");
        $_ = <STDIN>;
        chomp();
        unless(length($_)<=0){ $$str_input_filename_ref = $_; }
        else{ die("abort : empty filename\n"); }
    }
    unless( -f $$str_input_filename_ref){ die("error : ファイルが存在しない\n"); }

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

    # 登録済みネットラジオを削除するかどうか
    print("Bansheeに登録済みのネットラジオを削除する (y/n) [N] : ");
    $_ = <STDIN>;
    chomp;
    if(length($_)<=0){ $$mode_delete_radio_ref = 0; }
    elsif(uc($_) eq 'Y'){ $$mode_delete_radio_ref = 1; }
    elsif(uc($_) eq 'N'){ $$mode_delete_radio_ref = 0; }
    else { die("選択肢 Y/N 以外が入力されたため終了します") }

    return;
}

# プレイリストファイルからネットラジオ名称とURIを読み込んで配列に格納する
sub sub_read_from_pls{
    # 引数
    my $filepath = shift;   # 読み込むplaylist(PLS)ファイル名
    my $ref_arr = shift;    # PLSデータを格納する二次配列（へのリファレンス）

    my %hash_data;
    my $n_maxsuffix = 1;    # 添字（tilteキーの添字数字）の最大値

    print("PLSファイルを読込中 ...\n");

    unless( -f $filepath ){
        print("PLSファイル ".$filepath." が存在しません\n");
        return;
    }
    my $enc = sub_get_encode_of_file($filepath);
    if($flag_debug){ print("入力PLSの文字コード検出 : ".$enc."\n"); }


    # PLSファイルを読み込んで、ハッシュ形式に一旦格納する
    open(FH, '<'.$filepath) or return;
    while(<FH>){
        chomp;
        if(length($_)<3){ next; }   # 3文字以下は行スキップ
        my @arr = split(/=/, $_, 2);
        if($#arr != 1){ next; }     # = で分離できないときは行スキップ
        
        # キー名（title,file,lengthのいずれか）、値が存在することをチェック
        if($arr[1] eq '' and $arr[0] =~ m/^length[0-9]*$/i){ $arr[1] = '-1'; }  #lengthが空白の時は-1を代入（NetRadio）
        if($arr[0] eq '' or $arr[1] eq ''){ next; } # キー名or値が空白の時はスキップ
        unless($arr[0] =~ m/^title[0-9]*$/i or $arr[0] =~ m/^file[0-9]*$/i or $arr[0] =~ m/^length[0-9]*$/i){ next; }

        # キー・値のペアを一旦ハッシュに代入しておく
        if(!defined($hash_data{lc($arr[0])})){
            # 一致するキーがなければハッシュに代入
            $hash_data{lc($arr[0])} = sub_conv_to_flagged_utf8($arr[1], $enc);
        }
        else{
            print("重複キーをスキップ：".$arr[0]."\n");
        }
        
        # キー名 title 末尾の添数字の最大値を覚えておく
        if($arr[0] =~ m/title([0-9]*)/i){
            if($n_maxsuffix < $1){ $n_maxsuffix = $1; }
        }
    }
    close(FH);


    # 添字の小さい順にスキャンし、配列（リファレンス）に格納する
    my $n_added_count = 0;
    for(my $i=0; $i<=$n_maxsuffix; $i++){
        if(defined($hash_data{'title'.$i})){
            if($flag_debug){ print('title'.$i.'='.$hash_data{'title'.$i}."\n"); }
            my @arr = ($hash_data{'title'.$i},
                    defined($hash_data{'file'.$i}) ? $hash_data{'file'.$i} : '',
                    defined($hash_data{'length'.$i}) ? $hash_data{'length'.$i} : '-1'       
                    );
            push(@$ref_arr, [@arr]);
            $n_added_count++;   # 追加した個数をカウント
        }
    }
    
    print($n_added_count."件のデータがPLSファイルに確認されました\n");

    return;
}

# Banshee DBに登録する
sub sub_add_to_db{
    # 引数
    my $dsn = shift;        # DSN
    my $ref_arr = shift;    # PLSデータを格納する二次配列（へのリファレンス）

    my $CoreTracks_Table = 'CoreTracks';

    my $PrimarySourceID = sub_get_db_primarysource_id($dsn);
    if($flag_debug){ print("PrimarySourceID = ".$PrimarySourceID."\n"); }
    if($PrimarySourceID <= 0){ return; }

    my $AlbumID = sub_get_db_corealbums_id($dsn);
    if($flag_debug){ print("AlbumID = ".$AlbumID."\n"); }
    if($AlbumID <= 0){ return; }

    my $ArtistID = sub_get_db_coreartists_id($dsn);
    if($flag_debug){ print("ArtistID = ".$ArtistID."\n"); }
    if($ArtistID <= 0){ return; }

    print("Databaseに登録中 ...\n");

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

        # データを追加する
        my $n_added_count = 0;
        $str_sql = "INSERT INTO $CoreTracks_Table (PrimarySourceID,ArtistID,AlbumID,Uri,Title,TitleLowered,Genre) VALUES (?,?,?,?,?,?,'Radio')";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        
        for(my $i=0; $i<=$#$ref_arr; $i++){
            $sth->execute($PrimarySourceID,$ArtistID,$AlbumID,$ref_arr->[$i][1],$ref_arr->[$i][0],lc($ref_arr->[$i][0])) or die(DBI::errstr);
            $n_added_count++;
        }
        $sth->finish();
        print($n_added_count."件のデータをDatabaseに保存しました\n");

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

# CoreAlbums テーブルから "Net Radio" 項目のID番号を得る
sub sub_get_db_corealbums_id {
    # 引数
    my $dsn = shift;        # DSN

    my $CoreAlbums_Table = 'CoreAlbums';
    my $ret_id = -1;        # "InternetRadioSource" のID番号
    my $ArtistID = sub_get_db_coreartists_id($dsn);
    my $dbh = undef;
    eval{
        # SQLサーバに接続
        $dbh = DBI->connect($dsn, "", "", {PrintError => 0, AutoCommit => 1}) or die(DBI::errstr);

        # TABLEが存在するかクエリを行う
        my $str_sql = "select count(*) from sqlite_master where type='table' and name='$CoreAlbums_Table'";
        my $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        my @arr = $sth->fetchrow_array();
        $sth->finish();
        
        if($arr[0] != 1){
            if($flag_debug){ print("$CoreAlbums_Table TABLE check : NOT exist\n"); }
            # CoreAlbums が無い場合は corealbums で試す
            @arr = ();
            $CoreAlbums_Table = 'corealbums';
            my $str_sql = "select count(*) from sqlite_master where type='table' and name='$CoreAlbums_Table'";
            my $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
            $sth->execute() or die(DBI::errstr);
            my @arr = $sth->fetchrow_array();
            $sth->finish();
            if($arr[0] != 1){
                die("DatabaseにCoreAlbumsテーブルが見つからない\n");
            }
        }
       if($flag_debug){ print("$CoreAlbums_Table TABLE check : exist\n"); }
        
        @arr = ();

        # Titleが"InternetRadio"のものを検索する
        $str_sql = "SELECT count(*) FROM $CoreAlbums_Table WHERE Title LIKE '%InternetRadio%'";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        @arr = $sth->fetchrow_array();
        $sth->finish();
        if($arr[0] < 1){
            # AlbumIDの最大値を得る
            my $MaxAlbumID = 1;
            @arr = ();
            $str_sql = "SELECT max(AlbumID) FROM $CoreAlbums_Table";
            $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
            $sth->execute() or die(DBI::errstr);
            @arr = $sth->fetchrow_array();
            $sth->finish();
            if(defined($arr[0]) && $arr[0] >= 1){ $MaxAlbumID = $arr[0] + 1; }
            # 新規データ "InternetRadio" を作成する
            @arr = ();
            $str_sql = "INSERT INTO $CoreAlbums_Table (AlbumID,Title,TitleLowered,ArtistID,ArtistName,ArtistNameLowered) VALUES (?,'InternetRadio','internet radio',?,'InternetRadio','internet radio')";
            $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
            $sth->execute($MaxAlbumID, $ArtistID) or die(DBI::errstr);
            @arr = $sth->fetchrow_array();
            $sth->finish();
            if($flag_debug){ print("CoreAlbumsテーブルにInternetRadioを新規登録しました\n"); }
        }
        @arr = ();

        # Titleが"InternetRadio"のものを検索する
        $str_sql = "SELECT AlbumID FROM $CoreAlbums_Table WHERE Title LIKE '%InternetRadio%'";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        @arr = $sth->fetchrow_array();
        $sth->finish();
        if(!exists($arr[0]) || $arr[0] <= 0){ die("CoreAlbums TABLE異常"); }
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

# CoreArtists テーブルから "Net Radio" 項目のID番号を得る
sub sub_get_db_coreartists_id {
    # 引数
    my $dsn = shift;        # DSN

    my $CoreArtists_Table = 'CoreArtists';  # テーブル名
    my $ret_id = -1;        # "InternetRadioSource" のID番号
    my $dbh = undef;
    eval{
        # SQLサーバに接続
        $dbh = DBI->connect($dsn, "", "", {PrintError => 0, AutoCommit => 1}) or die(DBI::errstr);

        # TABLEが存在するかクエリを行う
        my $str_sql = "select count(*) from sqlite_master where type='table' and name='$CoreArtists_Table'";
        my $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        my @arr = $sth->fetchrow_array();
        $sth->finish();
        
        if($arr[0] != 1){
            if($flag_debug){ print("$CoreArtists_Table TABLE check : NOT exist\n"); }
            # CoreArtists が無い場合は coreartists で試す
            @arr = ();
            $CoreArtists_Table = 'coreartists';
            my $str_sql = "select count(*) from sqlite_master where type='table' and name='$CoreArtists_Table'";
            my $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
            $sth->execute() or die(DBI::errstr);
            my @arr = $sth->fetchrow_array();
            $sth->finish();
            print("DatabaseにCoreArtistsテーブルが見つからない\n");
            die;
        }
       if($flag_debug){ print("$CoreArtists_Table TABLE check : exist\n"); }
        @arr = ();

        # Titleが"InternetRadio"のものを検索する
        $str_sql = "SELECT count(*) FROM CoreArtists WHERE Name LIKE '%InternetRadio%'";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        @arr = $sth->fetchrow_array();
        $sth->finish();
        if($arr[0] < 1){
            # ArtistIDの最大値を得る
            my $MaxArtistID = 1;
            @arr = ();
            $str_sql = "SELECT max(ArtistID) FROM $CoreArtists_Table";
            $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
            $sth->execute() or die(DBI::errstr);
            @arr = $sth->fetchrow_array();
            $sth->finish();
            if(defined($arr[0]) && $arr[0] >= 1){ $MaxArtistID = $arr[0] + 1; }
            # 新規データ "InternetRadio" を作成する
            @arr = ();
            $str_sql = "INSERT INTO $CoreArtists_Table (ArtistID,Name,NameLowered) VALUES (?,'InternetRadio','internet radio')";
            $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
            $sth->execute($MaxArtistID) or die(DBI::errstr);
            @arr = $sth->fetchrow_array();
            $sth->finish();
            if($flag_debug){ print("CoreArtistsテーブルにInternetRadioを新規登録しました\n"); }
        }
        @arr = ();

        # Titleが"InternetRadio"のものを検索する
        $str_sql = "SELECT ArtistID FROM $CoreArtists_Table WHERE Name LIKE '%InternetRadio%'";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute() or die(DBI::errstr);
        @arr = $sth->fetchrow_array();
        $sth->finish();
        if(!exists($arr[0]) || $arr[0] <= 0){ die("CoreArtists TABLE異常"); }
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
    return($ret_id);}


sub sub_delete_radio_from_db{
    # 引数
    my $dsn = shift;        # DSN

    my $CoreTracks_Table = 'CoreTracks';

    print("Databaseに登録済みのネットラジオを削除中 ...\n");

    my $PrimarySourceID = sub_get_db_primarysource_id($dsn);
    if($flag_debug){ print("PrimarySourceID = ".$PrimarySourceID."\n"); }
    if($PrimarySourceID <= 0){ return; }

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
        $sth = undef;
        
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

        # ネットラジオ登録の行数を確認
        $str_sql = "select count(*) from $CoreTracks_Table WHERE PrimarySourceID = ?";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute($PrimarySourceID) or die(DBI::errstr);
        @arr = $sth->fetchrow_array();
        $sth->finish();
        $sth = undef;
        
        print("".$arr[0]." 件の登録済みネットラジオを削除中 ...\n");

        # データを削除する
        $str_sql = "DELETE FROM $CoreTracks_Table WHERE PrimarySourceID = ?";
        $sth = $dbh->prepare($str_sql) or die(DBI::errstr);
        $sth->execute($PrimarySourceID) or die(DBI::errstr);
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
  
