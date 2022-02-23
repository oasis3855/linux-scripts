#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : 
#   csv2gpx.pl : CSVをGPXファイルにコンバートする
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
use File::Basename;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my @arr_data;

print(STDERR "convert CSV tracking log into GPX\n");
if(@ARGV != 1){
    print(STDERR "usage: ".basename($0)." [track_csvfile]\n");
    exit();
}

my $str_filename = shift;
if(!( -f $str_filename)){
    print(STDERR "file not found\n");
    exit();
}

# CSVファイルを読み込み、配列に格納する
open(FH, "<".$str_filename) or die("file open error\n");
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

if($#arr_data < 0){
    print(STDERR "no data found in CSV\n");
    exit();
}
print(STDERR $#arr_data." track points found\n");

# GPXを出力する
# ファイル開始
printf("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n".
    "<gpx xmlns=\"http://www.topografix.com/GPX/1/1\" creator=\"csv2gpx.pl\" version=\"1.1\">\n".
    "<metadata>\n".
    "</metadata>\n".
    "<trk>\n".
    "<trkseg>\n");

# 地点マーカー
for(my $i=0; $i<=$#arr_data; $i++){
    # my ($sec,$min,$hour,$mday,$month,$year,$wday,$stime) = localtime($arr_data[$i][0]);
    my ($sec,$min,$hour,$mday,$month,$year,$wday,$stime) = gmtime($arr_data[$i][0]);
    my $str_date = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year+1900,$month+1,$mday,$hour,$min,$sec);
    printf("<trkpt lat=\"%s\" lon=\"%s\">\n".
        "<ele>%s</ele>\n".
        "<time>%s</time>\n".
        "</trkpt>\n",$arr_data[$i][1], $arr_data[$i][2], $arr_data[$i][3], $str_date);
}

# ファイル終了
print("</trkseg>\n".
    "</trk>\n".
    "</gpx>\n");

print(STDERR "done\n");
