#!/bin/sh

# 区切り文字を「改行」のみに変更
IFS_BACKUP=$IFS
IFS=$'
'

# ファイル情報を表示する
#file "$1" | leafpad
file "$1" | zenity --text-info --width=800 --height=400 --font=Mono --title="file" 2>/dev/null


# 区切り文字をもとに戻す
IFS=$IFS_BACKUP

