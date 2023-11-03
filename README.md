# MQL5
pwd : `/Users/kyamasaki/MetaTrader5/MQL5`


### pips
#### ログファイル読み込み
ログファイルはLogsディレクトリに出力される

ただし、ファイル読み込み関数はFilesディレクトリのファイルしかattachできないため以下のようにシンボリックリンクを貼る

`ln -s /Users/kyamasaki/MetaTrader5/MQL5/Logs /Users/kyamasaki/MetaTrader5/MQL5/Files/Logs`