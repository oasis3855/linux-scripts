#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : Gnome background image transition xml creater
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# gback-slideshow.pl
# version 0.1 (2011/April/20)
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
use Getopt::Long;
use File::Basename;

my $dulation_sec = 300;		# それぞれの画像表示時間
my $transition_sec = 0;		# 画像切り替え時間（秒）。0 の場合は transition を用いない

# プログラム引数を取り込む
GetOptions('dulation|d=i' => \ $dulation_sec,
                'transition|t=i' => \ $transition_sec);
# プログラム引数よりオプションスイッチを読み込んだ残りは、ファイル名
if($#ARGV < 0){ sub_print_usage(); exit; }	# 画像ファイルが指定されないとき
my @arr_imagefile = @ARGV;	# 画像ファイル（アスタリスクの検索展開済み）リストを読み込む

# 画像ファイル配列中より、ファイル以外を配列から除外する
for(my $i=0; $i<=$#arr_imagefile; $i++){
	unless( -f $arr_imagefile[$i] ){
		splice(@arr_imagefile, $i, 1);
		$i--;	# ポジションを一つ戻す
	}
}

my $str = "<background>\n".
	" <starttime>\n".
	"  <year>2011</year>\n".
	"  <month>01</month>\n".
	"  <day>01</day>\n".
	"  <hour>00</hour>\n".
	"  <minute>00</minute>\n".
	"  <second>00</second>\n".
	" </starttime>\n";
for(my $i=0; $i<=$#arr_imagefile; $i++){
	$str = $str . " <static>\n".
		"  <duration>".$dulation_sec."</duration>\n".
		"  <file>".$arr_imagefile[$i]."</file>\n".
		" </static>\n";
	
	if($transition_sec != 0){
		$str = $str . " <transition>\n".
			"  <duration>".$transition_sec."</duration>\n".
			"  <from>".$arr_imagefile[$i]."</from>\n".
			"  <to>".($i+1<=$#arr_imagefile ? $arr_imagefile[$i+1] : $arr_imagefile[0])."</to>\n".
			" </transition>\n";
	}
}
$str .= "</background>\n";

print $str;

exit;

sub sub_print_usage {
	print(STDERR "NAME\n".
		"    ".basename($0, '.pl')." - Gnome background image transition xml creater\n\n".
		"SYNOPSIS\n".
		"   ".basename($0)." [options] [imagefile scan path]\n\n".
		"OPTIONS\n".
		"    -d=num, -dulation=num\n".
		"        image change interval (sec). if not specified, use default 300 sec\n".
		"    -t=num, -transition=num\n".
		"        image transition interval (sec). if not specified, use default 0 sec\n\n".
		"EXAMPLES\n".
		"    ".basename($0)." -t=2 /usr/share/backgrounds/*.jpg > output.xml\n\n");

}
