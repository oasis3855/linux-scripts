#!/usr/bin/perl
#
# Google Cloud Platform : Maps Static API builder
# (C) 2018 INOUE Hirokazu
# GNU GPL Free Software  http://www.opensource.jp/gpl/gpl.ja.html
#
# 2018/October/06  Version 1.0

use strict;
use warnings;
use utf8;
use CGI;
use File::Basename 'basename';
use Encode;


binmode( STDIN, ":utf8" ); # コンソール入力があるコマンドライン版の時
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

my $str_this_script = basename($0); # このスクリプト自身のファイル名

my $param_center = "34.649344,135.001523";
my $param_zoom = 14;
my $param_size_height = 320;
my $param_size_width = 640;
my $param_scale = 1;
my $param_maptype = "roadmap";
my $param_language = "ja";
my $param_key = "";

my $uri_staticmap = '';

main();

exit;

sub main {
    my $q = new CGI;


    if(defined($q->param('showsrc'))){
        sub_show_src();
        return;
    }

    # HTML出力開始（ヘッダ）
    sub_print_start_html( \$q );


    if ( defined( $q->param('center') ) ) {
        $param_center = $q->param('center');
        my @param = split(/,/, $param_center);
        if($#param + 1 != 2) { $param[0] = 34.649344; $param[1] = 135.001523; }
        $param[0] += 0.0;
        $param[1] += 0.0;
        if($param[0] < -90.0 || 90.0 < $param[0]) { $param[0] = 34.649344; }
        if($param[1] < -180.0 || 180.0 < $param[1]) { $param[1] = 135.001523; }
        $param_center = $param[0] . ',' . $param[1];
    }
    if ( defined( $q->param('zoom') ) ) {
        $param_zoom = $q->param('zoom') + 0;
        if($param_zoom < 1 || $param_zoom > 20){ $param_zoom = 14; }
    }
    if ( defined( $q->param('size_height') ) ) {
        $param_size_height = $q->param('size_height') + 0;
        if($param_size_height < 1 || $param_size_height > 640){ $param_size_height = 320; }
    }
    if ( defined( $q->param('size_width') ) ) {
        $param_size_width = $q->param('size_width') + 0;
        if($param_size_width < 1 || $param_size_width > 640){ $param_size_width = 320; }
    }
    if ( defined( $q->param('scale') ) ) {
        $param_scale = $q->param('scale') + 0;
        if($param_scale != 1 && $param_scale != 2 && $param_scale != 4){ $param_scale = 1; }
    }
    if ( defined( $q->param('maptype') ) ) {
        $param_maptype = trim_space_tab($q->param('maptype'));
        if($param_maptype ne 'roadmap' && $param_maptype ne 'satellite'
            && $param_maptype ne 'hybrid' && $param_maptype ne 'terrain'){ $param_maptype = 'roadmap'; }
    }
    if ( defined( $q->param('language') ) ) {
        $param_language = trim_space_tab($q->param('language'));
        if(!check_string_alphanum($param_language)) { $param_language = ''; }
    }
    if ( defined( $q->param('key') ) ) {
        $param_key = trim_space_tab($q->param('key'));
        if(!check_string_alphanum($param_key)) { $param_key = ''; }
    }


    print("<p>Google Cloud Platform : Maps Static API builder</p>\n\n"
        . "<p>\n"
        . '  <a target="new" href="https://developers.google.com/maps/documentation/maps-static/intro">Maps Static API : Overview</a>,' . "\n"
        . '  &nbsp;&nbsp;&nbsp;<a target="new" href="https://developers.google.com/maps/documentation/maps-static/dev-guide">Developer Guide</a>,' . "\n"
        . '  &nbsp;&nbsp;&nbsp;[&nbsp;<a target="new" href="https://console.cloud.google.com/">open Console</a>&nbsp;],' . "\n"
        . '  &nbsp;&nbsp;&nbsp;<a href="' . $str_this_script . '?showsrc=true">このプログラムのソースコードを表示する</a>' . "\n"
        ."</p>\n\n"
        );

    # API引数のフォーム入力
    print "<!-- API引数のフォーム入力 -->\n"
      . '<form method="post" action="' . $str_this_script . "\">\n"
      . "  <table class=\"input_box\">\n"
      . '    <tr><td>座標 : center = </td><td><input type="text" name="center" size="30" value="'
      . $param_center . "\" />（経度,緯度）</td></tr>\n"

      . '    <tr><td>縮尺 : zoom = </td><td><input type="text" name="zoom" size="5" value="'
      . $param_zoom . "\" />（1=世界地図, 10=都市, 15=街区, 20=建物）</td></tr>\n"

      . '    <tr><td>画像サイズ : size = </td><td><input type="text" name="size_width" size="5" value="'
      . $param_size_width . '" /> x <input type="text" name="size_height" size="5" value="'
      . $param_size_height . "\" />（横x縦）最大 640x640</td></tr>\n"

      . "    <tr><td>拡大率 : scale = </td><td>\n"
      . '      <input type="radio" name="scale" value="1" ' . ($param_scale == 1 ? 'checked="checked"' : '') . '/> 1 (デフォルト値) ' . "\n"
      . '      <input type="radio" name="scale" value="2" ' . ($param_scale == 2 ? 'checked="checked"' : '') . '/> 2 ' . "\n"
      . '      <input type="radio" name="scale" value="4" ' . ($param_scale == 4 ? 'checked="checked"' : '') . '/> 4 ' . "\n"
      . "    </td></tr>\n"

      . "    <tr><td>地図の種類 : maptype = </td><td>\n"
      . '      <select name="maptype">' . "\n"
      . '      <option value="roadmap">roadmap (デフォルト値)</option>' . "\n"
      . '      <option value="satellite"' . ($param_maptype eq 'satellite' ? ' selected ' : '') . '>satellite</option>' . "\n"
      . '      <option value="hybrid"' . ($param_maptype eq 'hybrid' ? ' selected ' : '') . '>hybrid</option>' . "\n"
      . '      <option value="terrain"' . ($param_maptype eq 'terrain' ? ' selected ' : '') . '>terrain</option>' . "\n"
      . "      </select>\n"
      . "    </td></tr>\n"

      . "    <tr><td>言語 : language = </td><td>\n"
      . '      <select name="language">' . "\n"
      . '      <option value="ja">ja (日本語) デフォルト値</option>' . "\n"
      . '      <option value="zh-cn"' . ($param_language eq 'zh-cn' ? ' selected ' : '') . '>zh-cn (中国語 簡体字)</option>' . "\n"
      . '      <option value="zh-tw"' . ($param_language eq 'zh-tw' ? ' selected ' : '') . '>zh-tw (中国語 繁体字)</option>' . "\n"
      . '      <option value="en"' . ($param_language eq 'en' ? ' selected ' : '') . '>en (英語)</option>' . "\n"
      . '      <option value="de"' . ($param_language eq 'de' ? ' selected ' : '') . '>de (ドイツ語)</option>' . "\n"
      . '      <option value="fr"' . ($param_language eq 'fr' ? ' selected ' : '') . '>fr (フランス語)</option>' . "\n"
      . '      <option value="es"' . ($param_language eq 'es' ? ' selected ' : '') . '>es (スペイン語)</option>' . "\n"
      . '      <option value="el"' . ($param_language eq 'el' ? ' selected ' : '') . '>el (ギリシャ語)</option>' . "\n"
      . '      <option value="ru"' . ($param_language eq 'ru' ? ' selected ' : '') . '>ru (ロシア語)</option>' . "\n"
      . '      <option value="ar"' . ($param_language eq 'ar' ? ' selected ' : '') . '>ar (アラビア語)</option>' . "\n"
      . "      </select>\n"
      . "    </td></tr>\n"

      . '    <tr><td>API Key = </td><td><input type="text" name="key" size="40" value="'
      . $param_key . "\" /><br />（Console - menu - APIとサービス - Maps Static API - 認証情報よりキーを貼り付ける）</td></tr>\n"

      . '    <tr><td colspan="2"><input type="submit" value="地図を表示する" name="button_exec" /></td></tr>'

      . "\n  </table>\n"
      . "</form>\n\n";

    # Maps Static の URIを作成
    $uri_staticmap = 'https://maps.googleapis.com/maps/api/staticmap'
        . '?center=' . $param_center
        . '&zoom=' . $param_zoom
        . '&size=' . $param_size_width . 'x' . $param_size_height
        . ( $param_scale != 1 ? ( '&scale=' . $param_scale ) : '' )
        . ( $param_maptype ne '' ? '&maptype=' . $param_maptype : '' )
        . ( $param_language ne '' ? '&language=' . $param_language : '' )
        . ( $param_key ne '' ? ( '&key=' . $param_key ) : '' );



    # コード例の表示（URIのみ）
    my $uri_staticmap_escape = $uri_staticmap;
    $uri_staticmap_escape =~ s/[&]/&amp;/g;
    print "<!-- コード例（URIのみ）-->\n"
        . "<pre class=\"command_box\">\n"
        . $uri_staticmap_escape
        . "\n</pre>\n\n";

    # コード例の表示（HTML埋め込み）
    $uri_staticmap_escape =~ s/[&]/&amp;/g;
    print "<!-- コード例（HTML埋め込み）-->\n"
        . "<pre class=\"command_box\">\n"
        . '&lt;img src="'
        . $uri_staticmap_escape
        . '" alt="Staticmap"'
        . ' width="' . $param_size_width . '" height="' . $param_size_height . '"'
        . '&gt;'
        . "\n</pre>\n\n";

    # Staticmapの表示
    print "<!-- Staticmapの表示 -->\n"
        . "<img class=\"frame_box\" src=\""
        . $uri_staticmap
        . '" alt="Staticmap"'
        . ' width = "' . $param_size_width . '" height = "' . $param_size_height . '"'
        . ">\n\n";

    print "<p>API Keyを指定しない場合、地図は表示されなくなりました（2018/07〜）</p>\n";

    # HTML出力終了
    sub_print_close_html( \$q );
}


# htmlを開始する
sub sub_print_start_html {
    my $q_ref = shift;    # CGIオブジェクト
    print( $$q_ref->header( -type => 'text/html', -charset => 'utf-8' ) );
    print( $$q_ref->start_html(
                   -title => "Maps Static API code builder",
                   -dtd   => [
                       '-//W3C//DTD XHTML 1.0 Transitional//EN',
                       'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'
                   ],
                   -lang  => 'ja-JP',
                   -style => { 'src' => 'style.css' } ) );
}

# htmlを閉じる
sub sub_print_close_html {
    print("</body>\n</html>\n");
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

# 文字列前後の空白とタブ文字を削除
sub trim_space_tab {
    my $str = shift;
    $str =~ s/^\s*(.*?)\s*$/$1/;
    return $str;
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
