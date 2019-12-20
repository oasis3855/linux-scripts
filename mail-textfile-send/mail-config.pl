#!/usr/bin/perl

our $smtp_server = 'smtp.example.com';
our $smtp_portno = 587;
our $smtp_username = 'user@example.com';
# パスワードはbase64コマンドでエンコード（echo 'パスワード' | base64）
our $smtp_password_base64 = 'xyuThtYd29ybGQK';
our $from_name = '差出人の名前';
our $from = 'user@example.com';
