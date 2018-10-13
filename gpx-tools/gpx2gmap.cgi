#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name :
#   gpx2gmap.cgi : GPX/CSVをGoogleMap APIを用いたHTMLファイルにコンバートする
#
#   Version 1.0     2011/October/29
#   Version 1.1     2015/November/13
#   Version 1.2     2018/October/13
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
use Encode;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $str_this_script = basename($0);             # このスクリプト自身のファイル名

my $param_size_width = 50;
my $param_size_height = 480;
my $param_unit_width = '%';
my $param_unit_height = 'px';
my $param_maptype = 'roadmap';
my $str_html_icon = 'http://labs.google.com/ridefinder/images/mm_20_white.png';
my $str_html_color = 'blue';
my $int_max_uploadsize = 300*1024;    # CSVファイルの最大アップロードサイズ
my $flag_add_marker = 1;              # Web出力でmarkerを描画
my $flag_add_line = 1;                # Web出力でlineを描画
my $param_key = '';
my $param_server = 'maps.googleapis.com';
my $param_init = 'callback';


{
    my $str_tempfile = './data/upload.dat';       # アップロード時の一時ファイル名
    my $str_outputfile = './data/output.dat';     # 出力結果を一時的に格納するファイル名
    my $str_jsfile = './data/output.js';          # 出力結果を一時的に格納するファイル名
    my $str_file_ext = '';      # アップロードされたファイルの拡張子

    my $q = new CGI;

    # このスクリプトのソースコードを表示して終了する
    if(defined($q->param('showsrc'))){
        sub_show_src();
        exit;
    }

    # 引数を解析し、内部変数に格納する
    if(defined($q->param('uploadfile')) && length($q->param('uploadfile'))>0){
        if(defined($q->param('add_marker')) && length($q->param('add_marker'))>0 &&
                            $q->param('add_marker') eq 'enable'){
            $flag_add_marker = 1;
        }
        else { $flag_add_marker = 0; }

        if(defined($q->param('add_line')) && length($q->param('add_line'))>0 &&
                            $q->param('add_line') eq 'enable'){
            $flag_add_line = 1;
        }
        else { $flag_add_line = 0; }
    }

    if ( defined( $q->param('size_height') ) ) {
        $param_size_height = $q->param('size_height') + 0;
        if($param_size_height < 1 || $param_size_height > 1920){ $param_size_height = 640; }
    }
    if ( defined( $q->param('size_height') ) ) {
        $param_size_height = $q->param('size_height');
        if( decode_num_param(\$param_size_height, '%', 5, 100, 50) ) {
            $param_unit_height = '%';
        }
        elsif( decode_num_param(\$param_size_height, 'px', 100, 1920, 640) ) {
            $param_unit_height = 'px';
        }
        else {
            decode_num_param(\$param_size_height, '', 100, 1920, 640);
            $param_unit_height = 'px';
        }
    }
    if ( defined( $q->param('size_width') ) ) {
        $param_size_width = $q->param('size_width');
        if( decode_num_param(\$param_size_width, '%', 5, 100, 50) ) {
            $param_unit_width = '%';
        }
        elsif( decode_num_param(\$param_size_width, 'px', 100, 1920, 640) ) {
            $param_unit_width = 'px';
        }
        else {
            decode_num_param(\$param_size_width, '', 100, 1920, 640);
            $param_unit_width = 'px';
        }
    }

    if ( defined( $q->param('maptype') ) ) {
        $param_maptype = trim_space_tab($q->param('maptype'));
        if($param_maptype ne 'roadmap' && $param_maptype ne 'satellite'
            && $param_maptype ne 'hybrid' && $param_maptype ne 'terrain'){ $param_maptype = 'roadmap'; }
    }


    if ( defined( $q->param('key') ) ) {
        $param_key = trim_space_tab($q->param('key'));
        if(!check_string_alphanum($param_key)) { $param_key = ''; }
    }

    if ( defined( $q->param('server') ) ) {
        $param_server = trim_space_tab($q->param('server'));
        if($param_server ne 'maps.googleapis.com' && $param_server ne 'maps.google.cn'
            && $param_server ne 'maps.google.com'){ $param_server = 'maps.googleapis.com'; }
    }

    if ( defined( $q->param('init') ) ) {
        $param_init = trim_space_tab($q->param('init'));
        if($param_init ne 'callback' && $param_init ne 'window.onload'){ $param_server = 'callback'; }
    }

    my $flag_download_mode = 0;
    if(defined($q->param('uploadfile')) && length($q->param('uploadfile'))>0){
        # 結果のダウンロード／画面出力 ヘッダ出力を行う
        if(defined($q->param('export_to_file')) && length($q->param('export_to_file'))>0 &&
                $q->param('export_to_file') eq 'enable'){
            print "Content-Type: application/download\n";
            print "Content-Disposition: attachment; filename=\"MY_DRAWING_DATA.js\"\n\n";
            $flag_download_mode = 1;
        }
        else{
            # HTML出力開始（ヘッダ）
            sub_print_start_html( \$q );
            # GPX/CSVファイルアップロードのためのファイル選択画面
            sub_disp_upload_filepick();
        }
        # ファイルアップロード処理
        if(my $str_error = sub_upload_file(\$q, $str_tempfile, \$str_file_ext)){
            print("<p>sub_upload_csv error :".$str_error."</p>\n");
            sub_print_returnlink();
            print $q->end_html;
            exit;
        }
        # GPXファイルの場合、CSVデータに変換する
        if($str_file_ext eq '.gpx'){
            if(my $str_error = sub_gpx_to_csv($str_tempfile)){
                print("<p>sub_gpx_to_csv error :".$str_error."</p>\n");
                sub_print_returnlink();
                print $q->end_html;
                exit;
            }
        }
        # htmlファイル中の Maps JavaScript API 呼び出し部分を構築する
        my $str_script_call_html_code = '';
        sub_compose_script_call(\$str_script_call_html_code);
        # CSVデータをGoogleMaps API htmlに変換し、一時保存ファイルに保存
        if(my $str_error = sub_csv_to_gmap(\$q, $str_tempfile, $str_outputfile, $str_jsfile, $str_script_call_html_code)){
            print("<p>sub_csv_to_gmap error :".$str_error."</p>\n");
            sub_print_returnlink();
            print $q->end_html;
            exit;
        }
        # 結果の画面表示（サンプルHTMLコードの表示）
        if($flag_download_mode == 0) {
            my $str_code_escape = $str_script_call_html_code;
            $str_script_call_html_code =~ s/[&]/&amp;/g;
            $str_script_call_html_code =~ s/</&lt;/g;
            $str_script_call_html_code =~ s/>/&gt;/g;
            print(
                '<pre class="command_box">' . "\n"
                . $str_script_call_html_code . "\n"
                . '&lt;script type="text/javascript" src="MY_DRAWING_DATA.js"&gt;&lt;/script&gt;' . "\n"
                .'</pre>' . "\n"
            );
        }
        # 結果の画面表示（マップ領域HTMLコード）
        if($flag_download_mode == 0) {
            if(my $str_error = sub_output_result($str_outputfile)){
                print("<p>sub_output_result error :".$str_error."</p>\n");
                sub_print_returnlink();
                print $q->end_html;
                exit;
            }
        }
        else {
            delete_temp_file($str_outputfile);
        }
        # 結果の画面表示（マップ領域インラインJavaScriptコード）
        if(my $str_error = sub_output_result($str_jsfile)){
            print("<p>sub_output_result error :".$str_error."</p>\n");
            sub_print_returnlink();
            print $q->end_html;
            exit;
        }
        # 結果の画面表示（マップ領域HTMLコード）
        if($flag_download_mode == 0) {
            print("\n\n".
                    "-->\n".
                    "</script>\n");
        }
    }
    else{
        # HTML出力開始（ヘッダ）
        sub_print_start_html( \$q );
        # GPX/CSVファイルアップロードのためのファイル選択画面
        sub_disp_upload_filepick();
    }
    if($flag_download_mode == 0) {
        sub_print_returnlink();

        print $q->end_html;
    }

}

# GPX/CSVファイルアップロードのためのファイル選択画面
sub sub_disp_upload_filepick{
    print("<p>Google Cloud Platform : Maps JavaScript API code builder</p>\n\n"
        . "<p>\n"
        . '  <a target="new" href="https://developers.google.com/maps/documentation/javascript/tutorial?hl=ja">Maps JavaScript API : Overview</a>,' . "\n"
        . '  &nbsp;&nbsp;&nbsp;<a target="new" href="https://developers.google.com/maps/documentation/javascript/reference/?hl=ja">Reference </a>,' . "\n"
        . '  &nbsp;&nbsp;&nbsp;[&nbsp;<a target="new" href="https://console.cloud.google.com/">open Console</a>&nbsp;],' . "\n"
        . '  &nbsp;&nbsp;&nbsp;<a href="' . $str_this_script . '?showsrc=true">このプログラムのソースコードを表示する</a>' . "\n"
        ."</p>\n\n"
        );
    print("<!-- API引数のフォーム入力 -->\n"
        . '<form method="post" action="' . $str_this_script . '" enctype="multipart/form-data">' ."\n"
        . '  <table class="input_box">' . "\n"
        . '    <tr><td>GPX/CSVファイル</td><td>'
        . '<input type="file" name="uploadfile" value="" accept=".gpx, .csv" size="20" />'
        . '（最大サイズ ' . ($int_max_uploadsize/1024) . ' kBytes）</td></tr>' . "\n"
        . '    <tr><td></td><td><input type="checkbox" name="add_marker" value="enable" '
        . ($flag_add_marker == 1 ? 'checked="checked"' : '') . ' />Markerを出力'
        . '&nbsp;&nbsp;<input type="checkbox" name="add_line" value="enable" '
        . ($flag_add_line == 1 ? 'checked="checked"' : '') . ' />Polylineを出力</td></tr>' . "\n"

        . '    <tr><td>画像サイズ : size = </td><td><input type="text" name="size_width" size="5" value="'
        . $param_size_width . ( $param_unit_width eq '%' ? '%' : '' )
        . '" /> x <input type="text" name="size_height" size="5" value="'
        . $param_size_height . ( $param_unit_height eq '%' ? '%' : '' )
        . "\" />（横x縦）最大 1920x1920 または 0%-100%</td></tr>\n"

        . "    <tr><td>地図の種類 : maptype = </td><td>\n"
        . '      <select name="maptype">' . "\n"
        . '      <option value="roadmap">roadmap (デフォルト値)</option>' . "\n"
        . '      <option value="satellite"' . ($param_maptype eq 'satellite' ? ' selected ' : '') . '>satellite</option>' . "\n"
        . '      <option value="hybrid"' . ($param_maptype eq 'hybrid' ? ' selected ' : '') . '>hybrid</option>' . "\n"
        . '      <option value="terrain"' . ($param_maptype eq 'terrain' ? ' selected ' : '') . '>terrain</option>' . "\n"
        . "      </select>\n"
        . "    </td></tr>\n"

        . '    <tr><td>Marker出力ステップ</td><td>'
        . '<input type="text" name="marker_step" value="1" size="3" /> (1は１つ毎＝全て描画を意味する)</td></tr>' . "\n"

        . '    <tr><td>API Key = </td><td><input type="text" name="key" size="40" value="'
        . $param_key . "\" /><br />（Console - menu - APIとサービス - Maps Static API - 認証情報よりキーを貼り付ける）</td></tr>\n"

        . "    <tr><td>サーバ</td><td>\n"
        . '      <select name="server">' . "\n"
        . '      <option value="maps.googleapis.com">maps.googleapis.com (デフォルト値)</option>' . "\n"
        . '      <option value="maps.google.cn"' . ($param_server eq 'maps.google.cn' ? ' selected ' : '') . '>maps.google.cn</option>' . "\n"
        . '      <option value="maps.google.com"' . ($param_server eq 'maps.google.com' ? ' selected ' : '') . '>maps.google.com</option>' . "\n"
        . "      </select>\n"
        . "    </td></tr>\n"

        . "    <tr><td>JavaScript起動方法</td><td>\n"
        . '      <select name="init">' . "\n"
        . '      <option value="callback">callback (デフォルト値)</option>' . "\n"
        . '      <option value="window.onload"' . ($param_init eq 'window.onload' ? ' selected ' : '') . '>window.onload</option>' . "\n"
        . "      </select>\n"
        . "    </td></tr>\n"

        . '    <tr><td colspan="2"><input type="submit" value="アップロード" />'
        . '&nbsp;&nbsp;&nbsp;<input type="checkbox" name="export_to_file" value="enable" />Java Scriptをファイルに出力</td></tr>' . "\n"
        . "  </table>\n"
        . "</form>\n");
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

# htmlファイル中の Maps JavaScript API 呼び出し部分を構築する
sub sub_compose_script_call {
    my $str = shift;
    $$str = sprintf(
        '<script type="text/javascript" src="http://' . $param_server . '/maps/api/js?'
        . ($param_init eq 'callback' ? 'callback=initMap' : '' )
        . ($param_key ne '' ? '&key='.$param_key : '' )
        . '"' . ($param_init eq 'callback' ? ' async defer' : '' )
        . '></script>' ."\n"
        . "<div id=\"map_canvas\" style=\"width:" . $param_size_width . $param_unit_width
        . "; height:" . $param_size_height . $param_unit_height . ";background-color: #f4f2e9;\"></div>\n"
        . "<div class=\"clear\"></div>\n");
}

# 一時ファイルのCSVを読み込んで、GoogleMap API htmlに変換
sub sub_csv_to_gmap {
    # 引数
    my $q_ref = shift;
    my $str_csvfile = shift;
    my $str_outputfile = shift;
    my $str_jsfile = shift;
    my $str_script_call_html_code = shift;

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

    # HTML部分を出力用の一時ファイルに書き込む
    open(FH, ">".$str_outputfile) or return('temp output file open error');
    binmode(FH, ":utf8");
    printf(FH 
        $str_script_call_html_code
        . "<script type=\"text/javascript\">\n"
        . "<!--\n\n");


    close(FH);


    # Java Script部分を出力用の一時ファイルに書き込む
    open(FH, ">".$str_jsfile) or return('temp(js) output file open error');
    binmode(FH, ":utf8");
    printf(FH "/* Google Cloud Platform : Maps JavaScript API , route plotting map source code */"
        . ($param_init eq 'window.onload' ? '  window.onload = initMap;' : '' ) . "\n"
        . "function initMap() {\n"
        . " var myOptions = {\n"
        . " zoom: " . $gmap_zoom . ",\n"
        . " center: new google.maps.LatLng(%f,%f),\n"
#        . " mapTypeId: google.maps.MapTypeId." . $param_maptype . "\n"
        . " mapTypeId: '" . $param_maptype . "'\n"
        . " };\n"
        . " var myMap = new google.maps.Map(document.getElementById(\"map_canvas\"), myOptions);\n\n\n",
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
        print(FH "\n\n");
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

    print(FH "\n\n}\n\n");
    
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

sub delete_temp_file {
    my $str_outputfile = shift;
    # 一時ファイルを削除する
    unlink($str_outputfile);

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

# htmlを開始する
sub sub_print_start_html {
    my $q_ref = shift;    # CGIオブジェクト
    print( $$q_ref->header( -type => 'text/html', -charset => 'utf-8' ) );
    print( $$q_ref->start_html(
                   -title => "Maps JavaScript API code builder",
                   -dtd   => [
                       '-//W3C//DTD XHTML 1.0 Transitional//EN',
                       'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'
                   ],
                   -lang  => 'ja-JP',
                   -style => { 'src' => 'style.css' } ) );
}

# アルファベット、数字、"+-_" だけで文字列が構成される場合は 1
sub check_string_alphanum {
    my $str = shift || return(undef);
    if( $str =~ /^[a-zA-Z0-9\-\+_]{1,}$/ ){
        return(1);
    }
    # 英数字以外が含まれる
    else{
        return(0);
    }
}

# 数字だけで文字列が構成される場合は 1
sub check_string_num {
    my $str = shift || return(undef);
    if( $str =~ /^[0-9]{1,}$/ ){
        return(1);
    }
    # 数字以外が含まれる
    else{
        return(0);
    }
}

# 文字列前後の空白とタブ文字を削除
sub trim_space_tab {
    my $str = shift;
    $str =~ s/^\s*(.*?)\s*$/$1/;
    return $str;
}

# 単位付きの数値文字列を汚染除去・範囲内チェックを行う
sub decode_num_param {
    my ($ref_str, $suffix, $min, $max, $default) = @_;
    # 単位($suffix)が指定されている場合
    if( $suffix ne '' && $$ref_str =~ /^[0-9]+$suffix$/ ) {
        # 末尾の[$suffix]を削除
        $$ref_str = substr($$ref_str, 0, length($$ref_str)-length($suffix));
        # 文字列 → 数値 （汚染除去）
        if( check_string_num($$ref_str) != 1 ) { $$ref_str = $default; }
        $$ref_str = $$ref_str + 0;
        # 範囲外を除去
        if( $$ref_str < $min || $max < $$ref_str ) { $$ref_str = $default; }
        return 1;
    }
    # 単位($suffix)が指定されていない場合
    elsif( $suffix eq '' ) {
        # 文字列 → 数値 （汚染除去）
        if( check_string_num($$ref_str) != 1 ) { $$ref_str = $default; }
        $$ref_str = $$ref_str + 0;
        # 範囲外を除去
        if( $$ref_str < $min || $max < $$ref_str ) { $$ref_str = $default; }
        return 1;
    }
    else {
        return 0;
    }
}

# このスクリプトのソースコードを表示する
sub sub_show_src{
    # ソースコードのファイルを読み込む
    open(FH, "<".$str_this_script) or sub_file_error_exit();
    my @data = <FH>;
    close(FH);
    # 画面表示を行う
    print "Content-type: text/plain\n\n";
    foreach my $data_line (@data) {
        print decode('utf-8', $data_line);
    }
}

# ファイル読み込みエラーの場合の画面表示
sub sub_file_error_exit{
    print "Content-type: text/plain\n\n";
    print "Error : can't read source code.\n";
    exit();
}

