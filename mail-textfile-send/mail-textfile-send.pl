#!/usr/bin/perl
#
# SMTP経由でテキストメールを送信する（メール本文はテキストファイルから読み込む）
#
# 2019/Sep/23 Version 1.0
#
 
use warnings;
use strict;
use utf8;
use Net::SMTPS;
use Getopt::Long;
use File::Basename;
use FindBin;
use Encode::Guess qw/euc-jp shiftjis iso-2022-jp/;
use Encode qw(encode);
use MIME::Base64;

#my $config_filename = ((getpwuid($<))[7]).'/mail-config.pl';
my $config_filename = ($FindBin::Bin).'/mail-config.pl';
if(! -f $config_filename){
    print "config file $config_filename not found.";
    exit;
}
require $config_filename;    # メールサーバの認証データ読み込み

# mail-config.pl の書式
###############
#our $smtp_server = 'smtp.example.com';
#our $smtp_portno = 587;
#our $smtp_username = 'user@example.com';
# パスワードはbase64コマンドでエンコード（echo 'パスワード' | base64）
#our $smtp_password_base64 = 'xyuThtYd29ybGQK';
#our $from_name = '差出人の名前';
#our $from = 'user@example.com';
###############

my $flag_os = 'linux';  # linux/windows
my $flag_charcode = 'utf8';             # utf8/shiftjis

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

my $flag_debug = 0;     # デバッグ表示ONの場合は 1 を、表示なしの場合は 0 を入力

main();

sub main {
    our $from;                      # （必須）'user@example.com' (mail-config.plから読み込み)
    our $from_name;                 # （任意）'差出人の名前' (mail-config.plから読み込み)
    my $to        = '';             # （必須）'example@gmail.com'
    my $to_name   = '';             # （任意）'あて先の名前'
    my $subject   = 'test テスト';
    my $body      = '';             # ファイルから入力されるためのバッファ

    # プログラム引数を取り込む
    GetOptions('to=s' => \$to,
            'to_name=s' => \$to_name,
            'from=s' => \$from,
            'from_name=s' => \$from_name,
            'subject=s' => \$subject,
            'debug=i' => \$flag_debug);

    if(length($to)<=0 || length($to)>30 || length($from)<=0 || length($from)>30 ||
        length($from_name)>30 || length($to_name)>30 || length($subject)>50) {
        print "parameter error\n".
            " --to, --from : address must be specified, under 30 chars.\n".
            " --to_name, --from_name : name is option, under 30 chars.\n".
            " --subject : subject must be specified, under 50 chars.\n";
    }

    $to = sub_conv_to_flagged_utf8($to);
    $to_name = sub_conv_to_flagged_utf8($to_name);
    $subject = sub_conv_to_flagged_utf8($subject);

    if($flag_debug) {
        print "from    = ".$from_name." <".$from.">\n";
        print "to      = ".$to_name." <".$to.">\n";
        print "subject = ".$subject."\n";
    }

    ### 本文をファイルから読み込み、文字エンコードをutf8に揃える
    if($#ARGV != 0){
        sub_print_usage();
        exit;
    }
    my $input_filename = $ARGV[0];
    if($flag_debug) {
        print "file    = ".$input_filename."\n";
    }

    my $enc = undef;
    $enc = sub_get_encode_of_file($input_filename, $flag_debug);

    my $str_buf = '';
    if(open(IN, '< '.sub_conv_to_local_charset($input_filename))){
        $str_buf = join("", <IN>);
        close(IN);
    }
    if($str_buf ne '' ){ $str_buf = sub_conv_to_flagged_utf8($str_buf, $enc); }
    $body = $str_buf;
    if($flag_debug) {
        print "file contents = ".$body."\n";
    }


    our $smtp_server;   # メールサーバ (mail-config.plから読み込み)
    our $smtp_portno;   # ポート（例：587）(mail-config.plから読み込み)
    our $smtp_username; # ユーザ名 (mail-config.plから読み込み)
    our $smtp_password_base64;  # パスワードをbase64エンコードした文字列 (mail-config.plから読み込み)
    my $smtp_password = MIME::Base64::decode_base64($smtp_password_base64);
    chomp($smtp_password);

    if($flag_debug) {
        print "smtp server = '$smtp_server' \n";
        print "smtp port = '$smtp_portno' \n";
        print "smtp user = '$smtp_username' \n";
        print "password = '$smtp_password' \n";
    }

    my $smtp = Net::SMTPS->new($smtp_server,
                                Port  => $smtp_portno,
                                Timeout => 20,
                                doSSL => 'starttls',
                                Debug => $flag_debug ? 1 : 0
    );
    unless($smtp) {
        print "smtp connect error ($smtp_server:$smtp_portno)\n";
        exit;
    }
     
    if(!$smtp->auth($smtp_username, $smtp_password, 'CRAM-MD5' )) {
        print "smtp auth error ($smtp_username,$smtp_password)\n";
        exit;
    }
    $smtp->mail($from);
    $smtp->recipient( $to, SkipBad => 1 );
    $smtp->data();
     
    my $header_str =
        "From: " . encode( 'MIME-Header-ISO_2022_JP', $from_name ) . "<$from>\n"
      . "To: " . encode( 'MIME-Header-ISO_2022_JP', $to_name ) . "<$to>\n"
      . "Subject:" . encode( 'MIME-Header-ISO_2022_JP', $subject ) . "\n"
      . "Mime-Version: 1.0\n"
      . "Content-Type: text/plain; charset = \"ISO-2022-JP\"\n"
      . "Content-Trensfer-Encoding: 7bit\n\n";
     
    $smtp->datasend($header_str);
    $smtp->datasend( encode( 'iso-2022-jp', $body ) );
    $smtp->dataend();
    $smtp->quit;
}

# 任意の文字コードの文字列を、UTF-8フラグ付きのUTF-8に変換する
sub sub_conv_to_flagged_utf8{
    my $str = shift;
    my $enc_force = undef;
    if(@_ >= 1){ $enc_force = shift; }              # デコーダの強制指定
   
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
    my $fname = shift;              # 解析するファイル名
    my $flag_debug = shift;         # デバッグ表示の場合は 1 , 表示なしの場合は 0 

    # ファイルを一気に読み込む
    open(FH, "<".sub_conv_to_local_charset($fname));
    my @arr = <FH>;
    close(FH);
    my $str = join('', @arr);               # 配列を結合して、一つの文字列に

    my $enc = Encode::Guess->guess($str);   # 文字列のエンコードの判定

    # エンコード形式の表示（デバッグ用）
    if($flag_debug) { 
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
    }

    # エンコード形式が2個以上帰ってきた場合 （例：shiftjis or utf8）で検出失敗と扱う
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
                if($flag_debug) { 
                    print("HTML Content-Type detect : ". $content_enc ." (is overrided)\n");
                }
            }
        }
    }

    return($enc);
}


# ヘルプを表示する
sub sub_print_usage {
    print("NAME\n".
            "    ".basename($0, '.pl')." - send text mail\n\n".
            "SYNOPSIS\n".
            "   ".basename($0)." [options] [text filename]\n\n".
            "OPTIONS\n".
            "    --to=str\n".
            "        recipient mail address. ex : name\@example.com\n".
            "    --to_name=str\n".
            "        recipient name. if not specified, default is NULL string\n".
            "    --subject=str\n".
            "        mail subject. if not specified, default is 'test mail'\n".
            "EXAMPLES\n".
            "    ".basename($0)." test.txt --to=someone\@example.com --to_name=\"Some One\" --subject=\"Hello Mail\"\n\n"
            );
}
