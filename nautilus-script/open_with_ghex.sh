#!/bin/sh

# 区切り文字を「改行」のみに変更
IFS_BACKUP=$IFS
IFS=$'
'

ghex "$1"

# 区切り文字をもとに戻す
IFS=$IFS_BACKUP

