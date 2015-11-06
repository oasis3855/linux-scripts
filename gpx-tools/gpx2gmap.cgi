#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name :
#   gpx2gmap.cgi : GPX/CSVをGoogleMap APIを用いたHTMLファイルにコンバートする
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
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

use strict;
use warnings;
use utf8;
use CGI;
use File::Basename;
use File::Copy;
use HTTP::Date;
use XML::Simple;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $str_html_width = '650';
my $str_html_height = '480';
my $str_html_icon = 'http://labs.google.com/ridefinder/images/mm_20_white.png';
my $str_html_color = 'blue';
my $int_max_uploadsize = 300*1024;    # CSVファイルの最大アップロードサイズ
my $flag_add_marker = 1;              # Web出力でmarkerを描画
my $flag_add_line = 1;                # Web出力でlineを描画

{
    my $str_tempfile = './data/upload.dat';   # アップロード時の一時ファイル名
    my $str_outputfile = './data/output.dat';   # 出力結果を一時的に格納するファイル名
    my $str_file_ext = '';      # アップロードされたファイルの拡張子

    my $q = new CGI;

    if(defined($q->param('uploadfile')) && length($q->param('uploadfile'))>0){
        # 結果のダウンロード／画面出力 ヘッダ出力を行う
        if(defined($q->param('export_to_file')) && length($q->param('export_to_file'))>0 &&
                $q->param('export_to_file') eq 'enable'){
            print "Content-Type: application/download\n";
            print "Content-Disposition: attachment; filename=\"output.html.txt\"\n\n";
        }
        else{
            print $q->header(-type=>'text/html', -charset=>'utf-8');
        }
        # ファイルアップロード処理
        if(my $str_error = sub_upload_file(\$q, $str_tempfile, \$str_file_ext)){
            print $q->start_html(-title=>"Error",-lang=>'ja-JP');
            print("<p>sub_upload_csv error :".$str_error."</p>\n");
            sub_print_returnlink();
            print $q->end_html;
            exit;
        }
        # GPXファイルの場合、CSVデータに変換する
        if($str_file_ext eq '.gpx'){
            if(my $str_error = sub_gpx_to_csv($str_tempfile)){
                print $q->start_html(-title=>"Error",-lang=>'ja-JP');
                print("<p>sub_gpx_to_csv error :".$str_error."</p>\n");
                sub_print_returnlink();
                print $q->end_html;
                exit;
            }
        }
        # CSVデータをGoogleMaps API htmlに変換し、一時保存ファイルに保存
        if(my $str_error = sub_csv_to_gmap(\$q, $str_tempfile, $str_outputfile)){
            print $q->start_html(-title=>"Error",-lang=>'ja-JP');
            print("<p>sub_csv_to_gmap error :".$str_error."</p>\n");
            sub_print_returnlink();
            print $q->end_html;
            exit;
        }
        # 結果の画面表示
        if(my $str_error = sub_output_result($str_outputfile)){
            print $q->start_html(-title=>"Error",-lang=>'ja-JP');
            print("<p>sub_output_result error :".$str_error."</p>\n");
            sub_print_returnlink();
            print $q->end_html;
            exit;
        }
    }
    else{
        print $q->header(-type=>'text/html', -charset=>'utf-8');
        print $q->start_html(-title=>"アップロードファイルの選択",-lang=>'ja-JP');
        sub_disp_upload_filepick();
    }
    sub_print_returnlink();

    print $q->end_html;


}

# CSVファイルアップロードのためのファイル選択画面
sub sub_disp_upload_filepick{
    my $str_this_script = basename($0);             # このスクリプト自身のファイル名
    print("<p>GPSトラックログをWebページ上のGoogleMapsに埋め込むコードを作成</p>\n".
            "<p>&nbsp;</p>\n".
            "<form method=\"post\" action=\"$str_this_script\" enctype=\"multipart/form-data\">\n".
            "GPX/CSVファイルを指定します<br/>\n".
            "&nbsp;&nbsp;<input type=\"file\" name=\"uploadfile\" value=\"\" size=\"20\" />（最大サイズ ".($int_max_uploadsize/1024)." kBytes）<br />\n".
            "&nbsp;&nbsp;<input type=\"checkbox\" name=\"add_marker\" value=\"enable\" ".($flag_add_marker == 1 ? "checked=\"checked\"" : '')." />Markerを出力\n".
            "&nbsp;&nbsp;<input type=\"checkbox\" name=\"add_line\" value=\"enable\" ".($flag_add_line == 1 ? "checked=\"checked\"" : '')." />Polylineを出力\n".
            "&nbsp;&nbsp;<input type=\"checkbox\" name=\"export_to_file\" value=\"enable\"  />ファイルに出力<br/>\n".
            "&nbsp;&nbsp;Marker出力ステップ<input type=\"text\" name=\"marker_step\" value=\"1\" size=\"3\" /> (1は１つ毎＝全て描画を意味する) <br />\n".
            "<input type=\"submit\" value=\"アップロード\" />\n".
            "</form>\n");
}

sub sub_print_returnlink {
    my $str_this_script = basename($0);
    print("<p><a href=\"".$str_this_script."\">初期画面を再表示する</a></p>\n");
}


# CSV/GPXファイルをアップロード
sub sub_upload_file{
    # 引数
    my $q_ref = shift;
    my $str_tempfile = shift;
    my $str_file_ext_ref = shift;
    
    if(!defined($str_tempfile) || length($str_tempfile)<=0){
        return('parameter str_tempfile not defined');
    }

    # ユーザ側がアップロードしたファイル名から拡張子を切り出す
    my $str_filename = $$q_ref->param('uploadfile');
    my ($basename, $dirname, $ext) = fileparse($str_filename, qr/\.[^\.]+$/);
#    my ($basename, $dirname, $ext) = fileparse($str_filename, qr/\..*$/);
    $$str_file_ext_ref = lc($ext);
    if($$str_file_ext_ref ne '.csv' && $$str_file_ext_ref ne '.gpx'){
        return('file suffix must be CSV or GPX');
    }

    my $fh = $$q_ref->upload('uploadfile');
    my $str_temp_filepath = $$q_ref->tmpFileName($fh);
    File::Copy::move($str_temp_filepath, $str_tempfile) or return("temp file move error");
    close($fh);

    unless( -f $str_tempfile ){ return("temp file create error"); }
    
    # ファイルサイズが設定値を超えればエラー
    if( -s $str_tempfile < 1 || -s $str_tempfile > $int_max_uploadsize){
        unlink($str_tempfile);
        return('upload file size exceed '.($int_max_uploadsize/1024).'kBytes');
    }
    # テキストファイルかどうかを判定
    if(sub_test_file($str_tempfile) != 1){
        unlink($str_tempfile);
        return('upload file seems binary data or unsupported text');
    }
    
    return;
}

# GPXデータをCSVに変換
sub sub_gpx_to_csv {
    my $str_gpxfile = shift;

    # XMLファイルを読み込んで解析し、ハッシュ（%$ref）に格納
    my $xs = new XML::Simple();
    my $ref = $xs->XMLin($str_gpxfile);

    # データ数（0 ... $num）、データが存在しないときは -1
    my $num = $#{$ref->{'trk'}->{'trkseg'}->{'trkpt'}};

    if($num < 0){
        return("no data found in GPX(XML)\n");
    }

    open(FH, ">".$str_gpxfile) or return('internal file open error');
    binmode(FH, ":utf8");
        
    for(my $i=0; $i<=$num; $i++){
        # $i番目のtrack pointを抽出
        my %hash = %{$ref->{'trk'}->{'trkseg'}->{'trkpt'}->[$i]};
        # 時間、緯度経度、高度が全て揃っていない点はスキップ
        unless(defined($hash{'time'}) && defined($hash{'lat'}) &&
            defined($hash{'lon'}) && defined($hash{'ele'})){ next; }

        # 日時文字列（2011-10-23T04:52:06Z）をUNIX秒に変換
        my $timestr = $hash{'time'};
        $timestr = HTTP::Date::str2time($timestr);

        # 結果を出力（UNIX秒,緯度,経度,高度）
        print(FH $timestr.",".$hash{'lat'}.",".$hash{'lon'}.",".$hash{'ele'}."\n");

    }
    
    close(FH);

    return;
}

# 一時ファイルのCSVを読み込んで、GoogleMap API htmlに変換
sub sub_csv_to_gmap {
    # 引数
    my $q_ref = shift;
    my $str_csvfile = shift;
    my $str_outputfile = shift;

    my @arr_data;   # トラックポイント（時間、緯度経度、高度）のセットを格納する配列

    if(!defined($str_csvfile) || length($str_csvfile)<=0){
        return('parameter str_csvfile not defined');
    }
    if(!defined($str_outputfile) || length($str_outputfile)<=0){
        return('parameter str_outputfile not defined');
    }


    if(!( -f $str_csvfile)){
        return('str_csvfile not found');
    }

    # CSVファイルを読み込み、配列に格納する
    open(FH, "<".$str_csvfile) or return('csv file open error');
    while(my $str_line = <FH>){
        chomp($str_line);
        # 配列（$time,$latitude,$longitude,$altitude）に切り分ける
        my @arr = split(/\,/, $str_line);
        # 要素数が4で無い場合はスキップ
        if($#arr != 3){ next; }
        # 緯度-90〜+90、経度-180〜+180、高度-1000〜20000を外れればスキップ
        if($arr[1]<-90 || $arr[1]>90 || $arr[2]<-180 || $arr[2]>180 ||
            $arr[3]<-1000 || $arr[3]>20000){ next; }
        # 時間2000/1/1〜2032/1/1を外れればスキップ
        if($arr[0]<946652400 || $arr[0]>1956495659){ next; }
        # 配列に格納
        push(@arr_data, [@arr]);
    }
    close(FH);
    
    # CSVファイルを削除する
    unlink($str_csvfile);

    if($#arr_data < 0){
        return('no data found in CSV');
    }
#    print(STDERR $#arr_data." track points found\n");

    # 地図の中心を決定する（地点座標の重心）
    my $latitude_centre = 0;
    my $longitude_centre = 0;
    my $lat_max = -90.0;
    my $lat_min = 90.0;
    my $lon_max = -180.0;
    my $lon_min = 180.0;
    for(my $i=0; $i<$#arr_data; $i++){
        if($arr_data[$i][1] > $lat_max){ $lat_max = $arr_data[$i][1]; }
        if($arr_data[$i][1] < $lat_min){ $lat_min = $arr_data[$i][1]; }
        if($arr_data[$i][2] > $lon_max){ $lon_max = $arr_data[$i][2]; }
        if($arr_data[$i][2] < $lon_min){ $lon_min = $arr_data[$i][2]; }
    }
    $latitude_centre = ($lat_max + $lat_min)/2;
    $longitude_centre = ($lon_max + $lon_min)/2;
    
    # GoogleMapsのズームレベル設定する
    my $disp_angle = abs($lat_max - $lat_min);
    if($disp_angle < abs($lon_max - $lon_min)){
        $disp_angle = abs($lon_max - $lon_min);
    }
    
    my $gmap_zoom = '6';
    if($disp_angle < 0.005){ $gmap_zoom = '17'; }
    elsif($disp_angle < 0.01){ $gmap_zoom = '16'; }
    elsif($disp_angle < 0.02){ $gmap_zoom = '15'; }
    elsif($disp_angle < 0.04){ $gmap_zoom = '14'; }
    elsif($disp_angle < 0.08){ $gmap_zoom = '13'; }
    elsif($disp_angle < 0.16){ $gmap_zoom = '12'; }
    elsif($disp_angle < 0.32){ $gmap_zoom = '11'; }
    elsif($disp_angle < 0.64){ $gmap_zoom = '10'; }
    elsif($disp_angle < 1.3){ $gmap_zoom = '9'; }
    elsif($disp_angle < 2.7){ $gmap_zoom = '8'; }
    elsif($disp_angle < 5.4){ $gmap_zoom = '7'; }

    # 出力用の一時ファイルに書き込む
    open(FH, ">".$str_outputfile) or return('temp output file open error');
    binmode(FH, ":utf8");
    printf(FH "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"".
        "\"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n".
        "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"ja\" lang=\"ja\" dir=\"ltr\">\n".
        "<head>\n".
        "<title>GPS tracking route on GoogleMaps</title>\n".
        "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n".
        "<script type=\"text/javascript\" src=\"http://maps.google.com/maps/api/js?sensor=false\"></script>\n".
        "<script type=\"text/javascript\">\n".
        "<!--\n".
        " window.onload = initialize;\n".
        " function initialize() {\n".
        " var myOptions = {\n".
        " zoom: ".$gmap_zoom.",\n".
        " center: new google.maps.LatLng(%f,%f),\n".
        " mapTypeId: google.maps.MapTypeId.ROADMAP\n".
        " };\n".
        " var myMap = new google.maps.Map(document.getElementById(\"map_canvas\"), myOptions);\n",
        $latitude_centre, $longitude_centre);

    my $int_marker_step = 1;
    if(defined($$q_ref->param('marker_step')) && length($$q_ref->param('marker_step'))>0 &&
        $$q_ref->param('marker_step')>=1 && $$q_ref->param('marker_step')<=1000){
            $int_marker_step = int($$q_ref->param('marker_step'));
    }
    # 地点マーカーと吹出し
    if(defined($$q_ref->param('add_marker')) && length($$q_ref->param('add_marker'))>0 &&
                        $$q_ref->param('add_marker') eq 'enable'){
        for(my $i=0; $i<$#arr_data; $i++){
            if($i%$int_marker_step && $i!=$#arr_data-1){ next; }
            my ($sec,$min,$hour,$mday,$month,$year,$wday,$stime) = localtime($arr_data[$i][0]);
            my $str_date = sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year+1900,$month+1,$mday,$hour,$min,$sec);
            printf(FH " var marker%d = new google.maps.Marker({\n".
                "  map: myMap,\n".
                "  position: new google.maps.LatLng(%s,%s),\n".
                "  icon: \"".$str_html_icon."\",\n".
                "  title: \"time %s\",\n".
                " });\n", $i, $arr_data[$i][1],$arr_data[$i][2], $str_date);
                printf(FH " var infowindow%d = new google.maps.InfoWindow({\n".
                '  content: "日時 %s<br/>緯度 %s<br/>経度 %s<br/>高度 %s m",'."\n".
                " });\n".
                " google.maps.event.addListener(marker%d, 'click', function() {\n".
                "  infowindow%d.open(myMap, marker%d);\n".
                " });\n",$i, $str_date, $arr_data[$i][1], $arr_data[$i][2], $arr_data[$i][3], $i, $i, $i);
        }
    }

    # 地点の間を結ぶ線
    if(defined($$q_ref->param('add_line')) && length($$q_ref->param('add_line'))>0 &&
                        $$q_ref->param('add_line') eq 'enable'){
        print(FH " var polyline1 = new google.maps.Polyline({\n".
            "  map: myMap,\n".
            "  path: [\n");
        for(my $i=0; $i<$#arr_data; $i++){
            printf(FH "   new google.maps.LatLng(%s,%s),\n", $arr_data[$i][1],$arr_data[$i][2]);
        }
        print(FH "  ],\n".
            "  strokeColor: \"".$str_html_color."\",\n".
            "  strokeOpacity: 0.5,\n".
            "  strokeWeight: 3,\n".
            " });\n");
    }


    print(FH " }\n".
        "//-->\n".
        "</script>\n".
        "</head>\n".
        "<body>\n".
        "<div id=\"map_canvas\" style=\"width:".$str_html_width."px; height:".$str_html_height."px;\"></div>\n<div class=\"clear\"></div>\n");

    close(FH);
    
    return;
}

sub sub_output_result {
    my $str_outputfile = shift;

    if(!defined($str_outputfile) || length($str_outputfile)<=0){
        return('parameter str_outputfile not defined');
    }

    if(!( -f $str_outputfile)){
        return('str_outputfile not found');
    }

    open(FH,'<'.$str_outputfile) or return('temp output file open error');
    binmode(FH, ":utf8");
    while(my $str_line = <FH>){
        print($str_line);
    }
    close(FH);
    
    # 一時ファイルを削除する
    unlink($str_outputfile);

    return;
}

# CSV/GPX形式のテキストファイルか、中身をチェック
# 正常な場合は1を返す
sub sub_test_file {
    my $str_file = shift;

    # バイナリファイルのチェック
    if( -B $str_file ){ return; }
 

    open(FH,'<'.$str_file) or return;
    while(my $str_line = <FH>){
        chomp($str_line);
        $str_line =~ s/^(\s+|\t+)//m;   # 行頭の空白・タブ削除
        if(length($str_line) == 0){ next; }
        # GPX/XML形式のチェック（行頭 <?xml 文字）
        my @arr = split(/\s/, $str_line);
        if($#arr < 0){ return; }
        if(lc($arr[0]) eq '<?xml'){ return(1); }
        # CSV形式のチェック（４カラム、数値データ）
        @arr = split(/\,/, $str_line);
        if($#arr != 3){ return; }
        if($arr[0] != 0 && $arr[1] != 0 && $arr[2] != 0 && $arr[3] != 0){
            return(1);
        }
        return;
    }
    close(FH);
}
