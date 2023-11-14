# MQL5
pwd : `/Users/kyamasaki/MetaTrader5/MQL5`


### pips
#### ログファイル読み込み
ログファイルはLogsディレクトリに出力される

ただし、ファイル読み込み関数はFilesディレクトリのファイルしかattachできないため以下のようにシンボリックリンクを貼る

`ln -s /Users/kyamasaki/MetaTrader5/MQL5/Logs /Users/kyamasaki/MetaTrader5/MQL5/Files/Logs`


## EC2 Windowsインスタンス環境構築
### インスタンス作成
https://vps-ea.com/amazon-web-services/#toc6

### MT5インストール
https://www.xmtrading.com/jp/mt5

### gitインストール
https://prog-8.com/docs/git-env-win

MQLプログラムのあるgitリポジトリをクローン

### シンボリックリンク
個人作成のMQLプログラムをシンボリックリンク作成

`create-symlinks.bat`

### MT5で各種設定
1. メール送受信設定
2. アルゴリズム取引ON