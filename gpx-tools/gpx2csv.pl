#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : Web-Addrbook （Thunderbird連絡先管理DB）
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# gpx2csv.pl : GPXファイルをCSV形式にコンバートする
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
use File::Basename;
use HTTP::Date;
use XML::Simple;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

print(STDERR "convert GPX tracking log into CSV\n");

if(@ARGV != 1){
    print(STDERR "usage: ".basename($0)." [track_gpxfile]\n");
    exit();
}

my $str_filename = shift;
if(!( -f $str_filename)){
    print(STDERR "file not found\n");
    exit();
}

# XMLファイルを読み込んで解析し、ハッシュ（%$ref）に格納
my $xs = new XML::Simple();
my $ref = $xs->XMLin($str_filename);

# データ数（0 ... $num）、データが存在しないときは -1
my $num = $#{$ref->{'trk'}->{'trkseg'}->{'trkpt'}};

if($num < 0){
    print(STDERR "no data found in GPX(XML)\n");
    exit();
}
print(STDERR $num." track points is extracted from GPX(XML)\n");

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
    print($timestr.",".$hash{'lat'}.",".$hash{'lon'}.",".$hash{'ele'}."\n");

}

print(STDERR "done\n");
