#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Ubuntu Gnome indicator applet of IMAP4 mail checker
# 未読メール通知をGnomeインジケータに表示するアプレット for Ubuntu Linux
#
# (C) 2012 INOUE Hirokazu
# GNU GPL Free Software (GPL Version 2)
#
# Version 0.1 (2012/03/03)
# Version 0.2 (2012/05/08)
# Version 0.2.1 (2012/06/07)
# Version 0.3 (2012/06/08)
#

import sys
import gtk
import appindicator
import imaplib
import re
import pynotify
import os
import ConfigParser
import base64

#####
# GLOBAL VAR
# メールサーバ（IMAP4サーバ）：設定ファイルが自動作成されるので、ここを書き換える必要はない！
MAIL_SERVER = 'imap.example.com'
# メールサーバのログインユーザ名：設定ファイルが自動作成されるので、ここを書き換える必要はない！
MAIL_USER = 'user_name'
# メールサーバのログインパスワード：設定ファイルが自動作成されるので、ここを書き換える必要はない！
MAIL_PASSWORD = ''
# メールをチェックする間隔（秒）
CHECK_INTERVAL_SEC =  300    # sec
# 前回と同じ未読メール数の場合はポップアップ表示しない
#FLAG_NOPOPUP_UNREAD_SAME = True
FLAG_NOPOPUP_UNREAD_SAME = False
# メールソフト（MUA）の実行ファイル名（環境変数のパス内の場合はフルパス名は不要）
MUA_PROGRAM = 'thunderbird';
# メールソフト実行のメニュー表示文字列
MUA_MENU_STRING = 'Thunderbirdを起動'
# 前回チェック時の未読メール数（ポップアップ表示制御に利用）
prev_unread_count = 0



class CheckImapMail:
    #####
    # CheckImapMailクラス コンストラクタ
    def __init__(self):
        self.ind = appindicator.Indicator("new-imap-indicator",
                                           "indicator-messages",    # STATUS_ACTIVE のアイコンを設定
                                           appindicator.CATEGORY_APPLICATION_STATUS)
        self.ind.set_status(appindicator.STATUS_ACTIVE)     # 現状のステータスを STATUS_ACTIVE に設定
        self.ind.set_attention_icon("new-messages-red")     # STATUS_ATTENTION のアイコンを設定
        # コンテキストメニュー 設定
        self.menu_setup()
        self.ind.set_menu(self.menu)
        # 通知ポップアップの初期化
        if not pynotify.init("Mail Notifier"):
            sys.exit(-1)
        # 設定ファイルの読み込み（IMAP4サーバ名、ユーザ名、パスワード）
        self.config_file_read()

    #####
    # コンテキストメニュー 設定（クラスのコンストラクタから呼び出される）
    def menu_setup(self):
        self.menu = gtk.Menu()

        self.checknow_item = gtk.MenuItem("今すぐメールをチェック")
        self.checknow_item.connect("activate", self.menu_check_now)
        self.checknow_item.show()
        self.menu.append(self.checknow_item)

        self.checknow_item = gtk.MenuItem(MUA_MENU_STRING)
        self.checknow_item.connect("activate", self.menu_exec_mailprog)
        self.checknow_item.show()
        self.menu.append(self.checknow_item)

        self.config_item = gtk.MenuItem("設定")
        self.config_item.connect("activate", self.menu_config_dialog)
        self.config_item.show()
        self.menu.append(self.config_item)

        self.show_about_item = gtk.MenuItem("このプログラムについて")
        self.show_about_item.connect("activate", self.menu_about_dlg)
        self.show_about_item.show()
        self.menu.append(self.show_about_item)

        self.quit_item = gtk.MenuItem("終了")
        self.quit_item.connect("activate", self.menu_quit)
        self.quit_item.show()
        self.menu.append(self.quit_item)

    #####
    # メイン関数
    def main(self):
        # まずはじめに、メール確認
        self.check_mail()
        # タイマー設定（定期的に check_mail 関数を実行する）
        gtk.timeout_add(CHECK_INTERVAL_SEC * 1000, self.check_mail)
        gtk.main()

    #####
    # メニュー ： インジケータの終了
    def menu_quit(self, widget):
        dlg = gtk.MessageDialog(flags=gtk.DIALOG_MODAL, type=gtk.MESSAGE_INFO, buttons=gtk.BUTTONS_YES_NO, message_format='未読メール通知インジケータ')
        dlg.format_secondary_text('このインジケータを終了しますか？')
        ret = dlg.run()
        dlg.destroy()
        if ret == gtk.RESPONSE_YES:
            sys.exit(0)

    #####
    # メニュー ： パスワード入力ダイアログ
    def menu_config_dialog(self, widget):
        global MAIL_USER, MAIL_PASSWORD, MAIL_SERVER
        dlg = gtk.MessageDialog(type=gtk.MESSAGE_INFO, buttons=gtk.BUTTONS_OK_CANCEL, message_format='未読メール通知インジケータ')
        dlg.format_secondary_text('メールサーバのログオン情報を入力します')
        dlg_content = dlg.get_content_area()
        label_server = gtk.Label('メール（IMAP4）サーバ名')
        text_entry_server = gtk.Entry()
        text_entry_server.set_text(MAIL_SERVER)
        label_user = gtk.Label('ユーザ名')
        text_entry_user = gtk.Entry()
        text_entry_user.set_text(MAIL_USER)
        label_password = gtk.Label('パスワード')
        text_entry_password = gtk.Entry()
        text_entry_password.set_visibility(False)
        text_entry_password.set_text(MAIL_PASSWORD)
        dlg_content.add(label_server)
        dlg_content.add(text_entry_server)
        dlg_content.add(label_user)
        dlg_content.add(text_entry_user)
        dlg_content.add(label_password)
        dlg_content.add(text_entry_password)
        dlg.show_all()
        ret = dlg.run()
        text_server = text_entry_server.get_text().decode('utf8')
        text_user = text_entry_user.get_text().decode('utf8')
        text_password = text_entry_password.get_text().decode('utf8')
        dlg.destroy()
        if ret == gtk.RESPONSE_OK:
            MAIL_SERVER = text_server
            MAIL_USER = text_user
            MAIL_PASSWORD = text_password
            self.config_file_write()
            self.check_mail()

    #####
    # メニュー ： Aboutダイアログ
    def menu_about_dlg(self, widget):
        global MAIL_PASSWORD
        if MAIL_PASSWORD == '':
            dlg = gtk.MessageDialog(type=gtk.MESSAGE_WARNING, buttons=gtk.BUTTONS_OK, message_format='未読メール通知インジケータ')
            dlg.format_secondary_text('IMAPサーバにアクセスし、未読メールが存在する場合にポップアップを表示します\n\nパスワードが入力されていないため、メールチェックは行われていません')
            dlg.run()
            dlg.destroy()
        else:
            dlg = gtk.MessageDialog(type=gtk.MESSAGE_INFO, buttons=gtk.BUTTONS_OK, message_format='未読メール通知インジケータ')
            dlg.format_secondary_text('IMAPサーバにアクセスし、未読メールが存在する場合にポップアップを表示します')
            dlg.run()
            dlg.destroy()

    #####
    # メニュー ： 今すぐメールをチェック
    def menu_check_now(self, widget):
        self.check_mail()

    #####
    # メールチェックのメイン関数（タイマーが定期的にこの関数を呼び出す）
    def check_mail(self):
        global MAIL_SERVER
        global MAIL_USER
        global MAIL_PASSWORD
        global prev_unread_count
        
        # パスワードが未入力の場合（アイコンを変化させ、ポップアップを表示する）
        if MAIL_PASSWORD == '':
            self.ind.set_icon("error")     # STATUS_ACTIVE のアイコンを設定（接続断アイコン）
            self.ind.set_status(appindicator.STATUS_ACTIVE)
            dlg_notify = pynotify.Notification('未読メール通知インジケータ', 'パスワードが未入力です', "dialog-warning")
            dlg_notify.show()
            return True

        self.ind.set_icon("indicator-messages")     # STATUS_ACTIVE のアイコンを設定（ノーマル アイコン）
        # メールサーバからメッセージ数と未読メッセージ数を得る
        messages, unread = self.imap_mail_check(MAIL_SERVER, MAIL_USER, MAIL_PASSWORD)

        # メールサーバ接続エラーの場合（アイコンを変化させ、ポップアップを表示する）
        if messages == -1:
            self.ind.set_icon("error")     # STATUS_ACTIVE のアイコンを設定（接続断アイコン）
            self.ind.set_status(appindicator.STATUS_ACTIVE)
            dlg_notify = pynotify.Notification('未読メール通知インジケータ', 'メールサーバに接続できませんでした', "dialog-error")
            dlg_notify.show()
            return True
            
        # 未読メールが存在する場合
        if unread > 0:
            self.ind.set_status(appindicator.STATUS_ATTENTION)
            # 前回チェック時の未読数から増えている場合、ポップアップを表示
            if FLAG_NOPOPUP_UNREAD_SAME == False or prev_unread_count != unread :
                str_title = "%d 通の新着メールがあります" % unread
                str_msg = "%d 通のうち %d 通が未読です" % (messages, unread)
                dlg_notify = pynotify.Notification(str_title, str_msg, "mail-unread")
                dlg_notify.show()
                prev_unread_count = unread
                # 音を鳴らす
                os.system("/usr/bin/canberra-gtk-play --id='complete'")
                return True
        else:
            self.ind.set_status(appindicator.STATUS_ACTIVE)

        return True

    #####
    # メールサーバに接続し、INBOXの全メッセージ数、未読メッセージ数を得る
    def imap_mail_check(self, server, username, password):
        try:
            imap_instance = imaplib.IMAP4_SSL(server)
            imap_instance.login(username, password)
            x, y = imap_instance.status('INBOX', '(MESSAGES UNSEEN)')
            messages = int(re.search('MESSAGES\s+(\d+)', y[0]).group(1))
            unseen = int(re.search('UNSEEN\s+(\d+)', y[0]).group(1))
            imap_instance.logout()
            return (messages, unseen)
        except imaplib.IMAP4.error, e:
            dlg = gtk.MessageDialog(type=gtk.MESSAGE_WARNING, buttons=gtk.BUTTONS_OK, message_format='未読メール通知インジケータ')
            str_msg = 'IMAP4_SSL) メールサーバ接続時のエラー : %s\n' % e
            dlg.format_secondary_text(str_msg)
            dlg.run()
            dlg.destroy()
            # IMAP4エラーの場合、"メッセージ数"で-1を返す
            return -1, 0
        except:
            dlg = gtk.MessageDialog(type=gtk.MESSAGE_WARNING, buttons=gtk.BUTTONS_OK, message_format='未読メール通知インジケータ')
            str_msg = 'IMAP4_SSL) メールサーバ接続時のエラー : 原因不明\n'
            dlg.format_secondary_text(str_msg)
            dlg.run()
            dlg.destroy()
            # IMAP4エラーの場合、"メッセージ数"で-1を返す
            return -1, 0
            

    #####
    # メニュー ： メールソフトを起動する
    def menu_exec_mailprog(self, widget):
        os.spawnlp(os.P_NOWAIT, MUA_PROGRAM, MUA_PROGRAM)

    #####
    # 設定ファイルから読み込む
    def config_file_read(self):
        global MAIL_USER, MAIL_PASSWORD, MAIL_SERVER
        parser = ConfigParser.SafeConfigParser()
        configfile = os.path.join(os.environ['HOME'], '.imap4-newmail-indicator')

        try:
            fp = open(configfile, 'r')
            parser.readfp(fp)
            fp.close()
            MAIL_USER = parser.get("DEFAULT", "user")
            MAIL_PASSWORD = base64.b64decode(parser.get("DEFAULT", "password"))
            MAIL_SERVER = parser.get("DEFAULT", "server")
        except:
            # 設定ファイルが読み込めない場合、書き込みを行う（新規作成の時を意図）
            print >> sys.stderr, "config file error (not found or syntax error)"
            self.config_file_write()
            return

    #####
    # 設定ファイルに書き込む
    def config_file_write(self):
        global MAIL_USER, MAIL_PASSWORD, MAIL_SERVER
        parser = ConfigParser.SafeConfigParser()
        configfile = os.path.join(os.environ['HOME'], '.imap4-newmail-indicator')

        try:
            fp = open(configfile, 'w')
            parser.set("DEFAULT", "user", MAIL_USER)
            parser.set("DEFAULT", "password", base64.b64encode(MAIL_PASSWORD))
            parser.set("DEFAULT", "server", MAIL_SERVER)
            parser.write(fp)
            fp.close()
        except IOError:
            print >> sys.stderr, "config write error"


if __name__ == "__main__":
    indicator = CheckImapMail()
    indicator.main()

##### EOF
