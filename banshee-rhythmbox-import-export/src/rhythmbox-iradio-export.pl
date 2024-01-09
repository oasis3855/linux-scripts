#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : Rhythmbox のネットラジオ リストをPLS形式でエクスポートする
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# rhythmbox-iradio-export.pl
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
use XML::Simple;
#use Data::Dumper;

my $xml = new XML::Simple();
my $ref = $xml->XMLin($ENV{'HOME'}.'/.local/share/rhythmbox/rhythmdb.xml');

#print Data::Dumper->Dumper(\$ref);

my $i = 1;	# counter
foreach(@{$ref->{'entry'}}){
	if(lc($_->{'type'}) eq 'iradio'){
		print('Title'.$i.'='.$_->{'title'}."\n".
			'File'.$i.'='.$_->{'location'}."\n".
			'Length'.$i."=-1\n\n");
		$i++;
	}
}


