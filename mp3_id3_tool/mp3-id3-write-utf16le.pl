#!/usr/bin/perl

use warnings;
use strict;
use File::Basename;

# MP3::Tag::ID3v2 を UTF-16LE モードにする環境変数
$ENV{MP3TAG_USE_UTF_16LE} = 1;

my $script_dir = dirname(__FILE__);
my $script_path = $script_dir . ($script_dir =~ /\/$/ ? '':'/').'mp3-id3-write.pl';

unless( -f $script_path ){ die("mp3-id3-write.pl not found\n"); }

# system関数用 スクリプト起動パラメータ
my @exec_arg;
push(@exec_arg, 'perl');
push(@exec_arg, $script_path);
push(@exec_arg, @ARGV);

print("=== mp3-id3-write.pl UTF-16LE 版（Microsoft Media Player対応） ===\n");
system(@exec_arg);

