#!/bin/sh

# Gimp 2.10のExifタグ書き込みエラーに対応するため
# Makeタグが"PENTAX"の場合、"PENTAX Corp"に書き換えるスクリプト

# 区切り文字を「改行」のみに変更
IFS_BACKUP=$IFS
IFS=$'
'

DIR=`pwd`
[ -d "$1" ] && DIR=$DIR/`basename "$1"`

# 質問ダイアログの表示
#gdialog --title "Exif PENTAXタグ修正スクリプト" --yesno 'Gimp2.10のExifバグに対応するため、MakeタグのPENTAXをPENTAX Corpに書き換えます\n\n次のフォルダ内全ファイルのファイル名小文字化を行いますか？\n\n'"$DIR"
zenity --question --title="Exif PENTAXタグ修正スクリプト" --text="Gimp2.10のExifバグに対応するため、Makeタグの「PENTAX」を「PENTAX Corp」に書き換えます\n\n次のフォルダ内全ファイルのファイル名小文字化を行いますか？\n\n<b>$DIR</b>" --width=450 2>/dev/null

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
count_jpeg=0

for FULLPATH in *
do
    EXT=${FULLPATH##*.}
    if [ -f "$FULLPATH" ]
    then
        if [ $EXT = "jpg" -o $EXT = "jpeg" -o $EXT = "JPG" -o $EXT = "JPEG" ]
        then
            EXIF_MAKE=`exiftool -s -s -s -Make "$FULLPATH"`
            if [ -n "$EXIF_MAKE" -a  "$EXIF_MAKE" = "PENTAX" ]
            then
                exiftool -overwrite_original -Make="Pentax Corp." "$FULLPATH"
                count=`expr $count + 1`
            fi
            count_jpeg=`expr $count_jpeg + 1`
        fi
    fi
done

# 完了表示
#gdialog --title "Exif PENTAXタグ修正スクリプト" --infobox "対象ディレクトリ\n$DIR\n$count / $count_jpeg 個の対象ファイルが存在します"
zenity --info --title="Exif PENTAXタグ修正スクリプト" --text="対象ディレクトリ : $DIR\njpegファイル数 : $count_jpeg\n<b>書き換えたjpegファイル数 : $count</b>" --width=450 2>/dev/null
