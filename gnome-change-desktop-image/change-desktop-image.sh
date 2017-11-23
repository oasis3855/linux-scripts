#!/bin/sh

# デスクトップ画像をランダムに変更するスクリプト
# Copyright (C) INOUE Hirokazu
# http://oasis.halfmoon.jp/
#
# usage : 引数に画像ファイルが格納されたディレクトリを指定
#
# 定期的に変更する場合は crontab -e でこのスクリプトを動作させる


# 引数が1つ以外の場合、説明文を画面表示して終了
if [ $# -ne 1 ]
then
  echo "$0 : change desktop image randomly. usage : $0 [picture_dir]"
  exit 1
fi

DIR=$1

PID=$(pgrep gnome-session)
export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$PID/environ|cut -d= -f2-)


# 引数がディレクトリ名の場合は、デスクトップ画像を変更する"

if [ -d $DIR ]
then
  COUNT=$(find $DIR -maxdepth 1 -name '*.jpg' | wc -l)
  if [ $COUNT -le 0 ]
  then
    echo "$0 : warning, no jpeg file in directory($DIR)."
    exit 1
  else
    PIC=$(find $DIR -maxdepth 1 -name '*.jpg' | shuf -n1)
    gsettings set org.gnome.desktop.background picture-uri "file://$PIC"
  fi
else
  echo "$0 : warning, not a directory($DIR)."
  exit 1
fi

# eof

