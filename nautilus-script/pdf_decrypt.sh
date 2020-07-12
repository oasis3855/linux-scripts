#!/bin/sh

# 区切り文字を「改行」のみに変更
IFS_BACKUP=$IFS
IFS=$'
'

FULLPATH_ORG=`basename $1`

DIR=`pwd`
FILE=${FULLPATH_ORG%.*}
EXT=${FULLPATH_ORG##*.}

FULLPATH_MOD=${FILE}"-dec."${EXT}

if [ -f "$DIR/$FULLPATH_MOD" ]
then
    gdialog --title "pdf パスワード解除 - キャンセル" --infobox "同一名の出力ファイルが存在します\n処理を中止しました"
    exit
fi

MSG="PDFファイルのパスワード解除します\n\n  ディレクトリ: [$DIR]\n  変換元ファイル: [$FULLPATH_ORG]\n  変換先ファイル: [$FULLPATH_MOD]\n\nパスワードを入力してください（4 - 16文字）"


PASSWORD=$(gdialog --title "pdf パスワード解除" --inputbox "${MSG}" 0 0 ""  2>&1)
EXITCODE=$?

if [ $EXITCODE -ne 0 ]
then
    gdialog --title "pdf パスワード解除 - キャンセル" --infobox "キャンセルしました"
    IFS=$IFS_BACKUP
    exit
fi
LEN=${#PASSWORD}
if [ ${#PASSWORD} -lt 4 -o ${#PASSWORD} -gt 16 ]
then
    gdialog --title "pdf パスワード保護 - エラー" --infobox "パスワード長さ :["${LEN}"] が4-16文字内ではありません"
    IFS=$IFS_BACKUP
    exit
fi

#CMDLINE="pdftk \""$DIR"/"$FULLPATH_ORG"\" output \""$DIR"/"$FULLPATH_MOD"\" user_pw "$PASSWORD
CMDLINE="cd \"$DIR\";pdftk \"$FULLPATH_ORG\" input_pw $PASSWORD output \"$FULLPATH_MOD\""


gdialog --title "コマンドラインの表示" --yesno "次のコマンドを実行します\n\n$CMDLINE"
RESPONSE=$?

# yes=0, no=1, esc=255
case $RESPONSE in
    0) ;;
    1 | 255)
        gdialog --title "pdf パスワード解除 - キャンセル" --infobox "キャンセルしました"
        IFS=$IFS_BACKUP
        exit 0;;
esac

eval ${CMDLINE}

if [ $? -eq 0 ]
then
    gdialog --title "pdf パスワード解除 - 処理完了" --infobox "パスワード解除の処理成功しました（戻り値:0）"
else
    gdialog --title "pdf パスワード解除 - 処理完了" --infobox "処理失敗しました（戻り値:0以外）"
fi

# 区切り文字をもとに戻す
IFS=$IFS_BACKUP

