## SMTPサーバを利用するテキストメール送信Perlスクリプト<br />SMTP text mail sender, Perl script<!-- omit in toc -->

[Home](https://oasis3855.github.io/webpage/) > [Software](https://oasis3855.github.io/webpage/software/index.html) > [Software Download](https://oasis3855.github.io/webpage/software/software-download.html) > [linux-scripts](../README.md) > ***mail-textfile-send*** (this page)

<br />
<br />

Last Updated : Sep. 2019

- [ソフトウエアのダウンロード](#ソフトウエアのダウンロード)
- [概要](#概要)
  - [コマンドラインでの実行イメージ](#コマンドラインでの実行イメージ)
- [SMTP認証情報](#smtp認証情報)
- [動作確認](#動作確認)
- [バージョン情報](#バージョン情報)
- [ライセンス](#ライセンス)

<br />
<br />

## ソフトウエアのダウンロード

- [このGitHubリポジトリを参照する（ソースコード）](../mail-textfile-send/)

## 概要

```Net::SMTPS```ライブラリを用いたテキストメール送信スクリプト。事前に設定ファイルに格納したSMTPサーバの認証情報を利用し、任意の相手先にテキストメールを送信する

ここで配布しているスクリプトをカスタマイズして利用するためのテンプレート的な利用法を想定している

### コマンドラインでの実行イメージ

メール本文を```test.txt```に格納した上で、次のコマンドを実行する

```Bash
perl mail-textfile-send.pl --to=example0135@gmail.com --to_name="Example User" --subject="Test Mail"  test.txt

```

## SMTP認証情報

```mail-config.pl```にSMTPサーバの認証情報をあらかじめ設定する

```Perl
our $smtp_server = 'smtp.example.com';
our $smtp_portno = 587;
our $smtp_username = 'user@example.com';
# パスワードはbase64コマンドでエンコード（echo 'パスワード' | base64）
our $smtp_password_base64 = 'xyuThtYd29ybGQK';
our $from_name = '差出人の名前';
our $from = 'user@example.com';
```

## 動作確認

- Ubuntu 18.04


## バージョン情報

- Version 1.0 (2019/Sep/23)

## ライセンス

このスクリプトは [GNU General Public License v3ライセンスで公開する](https://gpl.mhatta.org/gpl.ja.html) フリーソフトウエア




