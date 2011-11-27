#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : Address Book CSV converter 住所録CSV相互変換 
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# addrbook_conv.pl
# version 0.1 (2011/November/27)
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
use Encode::Guess qw/euc-jp shiftjis iso-2022-jp/;	# 必要ないエンコードは削除すること

use Text::CSV_XS;
use Data::Dumper;

my $flag_os = 'linux';	# linux/windows
my $flag_charcode = 'utf8';		# utf8/shiftjis

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
	print("\n".basename($0)." - Convert Address Book CSV\n\nusage : ".basename($0)." [input CSV fiename] [output CSV filename]\n");

	my $str_input_filename = '';
	my $str_output_filename = '';
	my $mode_template = '';
	my $mode_output_encode = 'utf8';
	my $mode_csv_escape = 1;

	sub_user_input(\$str_input_filename, \$str_output_filename,
		\$mode_template, \$mode_output_encode, \$mode_csv_escape);

	my @arr_output_csv;
	sub_read_csv($str_input_filename, $mode_template, \@arr_output_csv);
	sub_write_csv($str_output_filename, \@arr_output_csv, $mode_output_encode, $mode_csv_escape);
}

# 入出力ファイル名や処理選択肢のユーザ入力
sub sub_user_input{
	# 引数
	my $str_input_filename_ref = shift;
	my $str_output_filename_ref = shift;
	my $mode_template_ref = shift;
	my $mode_output_encode_ref = shift;
	my $mode_csv_escape_ref = shift;

	# 入力ファイルのユーザ入力・指定
	if($#ARGV >= 0 && length($ARGV[0])>1){
		$$str_input_filename_ref = sub_conv_to_flagged_utf8($ARGV[0]);
	}
	else{
		print("入力CSVファイル名 : ");
		$_ = <STDIN>;
		chomp();
		unless(length($_)<=0){ $$str_input_filename_ref = $_; }
		else{ die("abort : empty filename\n"); }
	}
	unless( -f $$str_input_filename_ref){ die("error : ファイルが存在しない\n"); }

	# 出力ファイルのユーザ入力・指定
	if($#ARGV >= 1 && length($ARGV[1])>1){
		$$str_output_filename_ref = sub_conv_to_flagged_utf8($ARGV[1]);
	}
	else{
		print("出力CSVファイル名 : ");
		$_ = <STDIN>;
		chomp();
		unless(length($_)<=0){ $$str_output_filename_ref = $_; }
		else{ die("abort : empty filename\n"); }
	}

	# テンプレートファイルの選択
	print("変換テンプレートの選択\n 1: Thunderbird -> GMail\n 2: GMail -> Thunderbird\n 3: Thunderbird -> Aprint(葉書宛先印刷)\n 選択してください (1 - 3) [1] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0){ $$mode_template_ref = 'addrconv_tb_gm.csv'; }
	elsif(uc($_) eq '1'){ $$mode_template_ref = 'addrconv_tb_gm.csv'; }
	elsif(uc($_) eq '2'){ $$mode_template_ref = 'addrconv_gm_tb.csv'; }
	elsif(uc($_) eq '3'){ $$mode_template_ref = 'addrconv_tb_aprint.csv'; }
	else { die("選択肢 1-3 以外が入力されたため終了します") }

	my $str_basedir = ( File::Basename::fileparse($0) )[1];
	$$mode_template_ref = $str_basedir . $$mode_template_ref;

	# 出力文字コードの選択
	print("出力文字コードの選択\n 1: utf8\n 2: shift jis\n 選択してください (1 - 2) [1] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0){ $$mode_output_encode_ref = 'utf8'; }
	elsif(uc($_) eq '1'){ $$mode_output_encode_ref = 'utf8'; }
	elsif(uc($_) eq '2'){ $$mode_output_encode_ref = 'sjis'; }
	else { die("選択肢 1-2 以外が入力されたため終了します") }

	# CSVエスケープ処理の選択
	print("CSVデータのエスケープ処理の有無\n 1: ON (特殊文字は\"〜\"で囲みます)\n 2: OFF\n 選択してください (1 - 2) [1] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0){ $$mode_csv_escape_ref = 1; }
	elsif(uc($_) eq '1'){ $$mode_csv_escape_ref = 1; }
	elsif(uc($_) eq '2'){ $$mode_csv_escape_ref = 0; }
	else { die("選択肢 1-2 以外が入力されたため終了します") }

}

# 入力CSVファイルを読み込んで、出力CSV形式の配列に格納する
sub sub_read_csv{
	# 引数
	my $str_input_filename = shift;			# 入力CSVファイル
	my $str_datastruct_filename = shift;	# 変換定義ファイル
	my $arr_output_csv_ref = shift;		# 出力CSVデータを格納する2次元配列

	# 内部カラム名とCSVファイル固有のカラム名の対応関係の2次配列を作成
	my @arr_coord;
	open(FH, '<'.$str_datastruct_filename) or die("error : 変換テンプレートファイルが開けない\n");
	while(<FH>){
		chomp;
		my $str_line = sub_conv_to_flagged_utf8($_);
		my @arr = split(/\,/, $str_line);
		my @arr_temp;
		$arr_temp[0] = (defined($arr[0]) ? $arr[0] : '');		# 例 arr[0] = 'name_family'
		$arr_temp[1] = (defined($arr[1]) ? $arr[1] : '');		# 例 arr[1] = '姓'
		push(@arr_coord, [@arr_temp]);
	}
	close(FH);
	
	# 出力CSV配列の最初の行は、要素名
	my @arr_temp = ();
	foreach(@arr_coord){ push(@arr_temp, @$_[0]); }
	push(@$arr_output_csv_ref, [ @arr_temp ]);


	# CSVファイルの文字エンコードを得る（ファイル全体からエンコード形式を推測する）
	my $enc = sub_get_encode_of_file($str_input_filename);

	# CSVデータに日本語を使う場合の設定
	my $csv = Text::CSV_XS->new({binary=>1});

	open(FH_IN, '<'.sub_conv_to_local_charset($str_input_filename)) or die("error : input CSV open error\n");

	# CSVファイル1行目はカラム名の列挙
	my $str_line = <FH_IN>;
	$str_line = sub_conv_to_flagged_utf8($str_line, $enc);
	$csv->parse($str_line);
	my @arr_keyname = $csv->fields();

	while(<FH_IN>)
	{
		my $str_line = $_;
		if($str_line eq ''){ next; }
		$str_line = sub_conv_to_flagged_utf8($str_line, $enc);
#		print("$str_line\n");
		$csv->parse($str_line) or next;
		my @arr_fields = $csv->fields();
		# 要素数が1行目のカラム名一覧の要素数より少なければスキップ
		if($#arr_fields < 1 || $#arr_fields > $#arr_keyname){ next; }
		# CSV各1行ずつ、ハッシュに格納する
		my %hash_elem;
		for(my $i=0; $i<=$#arr_fields; $i++){
			$hash_elem{$arr_keyname[$i]} = $arr_fields[$i];
		}

		my @arr_temp = ();
		for(my $i=0; $i<=$#arr_coord; $i++){
			if($arr_coord[$i][1] eq ''){ push(@arr_temp, ''); }
			elsif($arr_coord[$i][1] =~ /^#/){
				# カラム名（変換式）の1文字目が # の時は、式ではなく、値そのものの
				push(@arr_temp, substr($arr_coord[$i][1], 1));
			}
			else{
				my @arr_elem = split(/\+/, $arr_coord[$i][1]);
				my $str_temp = '';
				foreach(@arr_elem){
					if($_ eq ''){ }
					elsif($_ eq ' '){ $str_temp .= ' '; }
					elsif($_ =~ /^#/){ $str_temp .= substr($_, 1); }
					else{ $str_temp .= (defined($hash_elem{$_}) ? $hash_elem{$_} : ''); }
				}
				push(@arr_temp, $str_temp);
			}
		}
		push(@$arr_output_csv_ref, [ @arr_temp ]);
	}

	close(FH_IN);
}


sub sub_write_csv{
	my $str_output_filename = shift;
	my $arr_output_csv_ref = shift;		# 出力CSVデータを格納する2次元配列
	my $mode_output_encode = shift;
	my $mode_csv_escape = shift;

	# 出力ファイルの存在チェック、書き込み不可の場合はエラー終了
	if( -f $str_output_filename ){
		print("overwrite to ".$str_output_filename."\n");
		unless( -w $str_output_filename ){ die("error : 出力CSVファイルに書き込めない\n"); }
	}
	elsif( -e $str_output_filename ){
		die("error : 出力ファイル名が既に使われていて、上書きできない\n");
	}


	eval{
		open(FH_OUT, '>'.sub_conv_to_local_charset($str_output_filename)) or die;
		if($mode_output_encode eq 'utf8'){ binmode(FH_OUT, 'utf8'); }
		elsif($mode_output_encode eq 'sjis'){ binmode(FH_OUT, "encoding(sjis)"); }

		my $csv = Text::CSV_XS->new({binary=>1});
		foreach(@$arr_output_csv_ref){
			if($mode_csv_escape == 1){
				$csv->combine(@$_);
				print(FH_OUT $csv->string()."\n");
			}
			else{
				foreach(@$_){ print(FH_OUT $_.','); }
				print(FH_OUT "\n");
			}
		}

		close(FH_OUT);
	};
	if($@){
		# evalによるエラートラップ：エラー時の処理
		print("error at writing file : ".$@."\n");
		exit;
	}

}


###########################################
# 共通関数からインポート

# 任意の文字コードの文字列を、UTF-8フラグ付きのUTF-8に変換する
sub sub_conv_to_flagged_utf8{
	my $str = shift;
	my $enc_force = undef;
	if(@_ >= 1){ $enc_force = shift; }		# デコーダの強制指定
	
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

	my $enc = Encode::Guess->guess($str);	# 文字列のエンコードの判定

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
	my $fname = shift;		# 解析するファイル名

	# ファイルを一気に読み込む
	open(FH, "<".sub_conv_to_local_charset($fname));
	my @arr = <FH>;
	close(FH);
	my $str = join('', @arr);		# 配列を結合して、一つの文字列に

	my $enc = Encode::Guess->guess($str);	# 文字列のエンコードの判定

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
