#!/bin/sh

# ファイル名を拡張子も含めて全て小文字ASCII文字に変更する
# （パス名に空白文字を含んだ場合に対応するため ＄IFS を改行のみに切り替えて処理）

# 区切り文字を「改行」のみに変更
IFS_BACKUP=$IFS
IFS=$'
'

DIR=`pwd`
[ -d "$1" ] && DIR=$DIR/`basename "$1"`


# 質問ダイアログの表示
gdialog --title "ファイル名小文字化" --yesno '次のフォルダ内全ファイルのファイル名小文字化を行いますか？\n\n'"$DIR"
RESPONSE=$?

# yes=0, no=1, esc=255
case $RESPONSE in
    0) ;;
    1)  IFS=$IFS_BACKUP 
        exit 0;;
    255)
        IFS=$IFS_BACKUP
        exit 0;;
esac


# 区切り文字をもとに戻す
IFS=$IFS_BACKUP

cd "$DIR"

count=0

for filename in *
do
    [ -f $filename ] && mv -i $filename `echo $filename | tr '[A-Z]' '[a-z]'` && count=`expr $count + 1`
done

# 完了表示
#echo $LOGSTR | leafpad
gdialog --title "ファイル名小文字化" --infobox "対象ディレクトリ\n$DIR\n$count個のファイルの小文字化を完了"

