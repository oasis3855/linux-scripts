#!/bin/sh
#
# 画像ファイルのExif情報を表示する

# 区切り文字を「改行」のみに変更
IFS_BACKUP=$IFS
IFS=$'
'

#exiftool "$1" | leafpad
exiftool -G "$1" | zenity --text-info --width=800 --height=400 --font=Mono --title="exiftool" 2>/dev/null

# 区切り文字をもとに戻す
IFS=$IFS_BACKUP

