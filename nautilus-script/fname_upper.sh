#!/bin/sh

# ファイル名を拡張子も含めて全て小文字ASCII文字に変更する
# （パス名に空白文字を含んだ場合に対応するため ＄IFS を改行のみに切り替えて処理）

# 区切り文字を「改行」のみに変更
IFS_BACKUP=$IFS
IFS=$'
'

# 引数ファイル一覧を改行区切り文字列にする（画面表示用）
ARGSTR=''
for fullpath in $*
do
    ARGSTR=$ARGSTR'\n'$fullpath
done
# 質問ダイアログの表示
gdialog --title "ファイル名大文字化" --yesno '次のファイルのファイル名大文字化を行いますか？\n\n'"$ARGSTR"
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

# スクリプト実行結果を表示するログ文字列
LOGSTR='スクリプト引数 = '"$*"'\n=== 処理結果表示 ===\n'

#for fullpath in $NAUTILUS_SCRIPT_SELECTED_FILE_PATHS   .... これは最初の1ファイルしか処理されない
for fullpath in $*
do
    # ディレクトリ名がある場合は取り去る
    name=`basename $fullpath`
    # ファイル名変換
    mv -i $name `echo $name | tr '[a-z]' '[A-Z]'`
    # ログ文字列への追加
    LOGSTR=$LOGSTR'\n'$name' => '`echo $name | tr '[a-z]' '[A-Z]'`
done

# 区切り文字をもとに戻す
IFS=$IFS_BACKUP

# ログ文字列を画面表示
#echo $LOGSTR | leafpad
gdialog --title "ファイル名小文字化" --infobox "$LOGSTR"

