## 概要
Expertのログを読み込んで指定文字を含む行を検知したらメールで検知する

### スクリプト
`python スクリプトパス -d ログディレクトリ -t 対象日 -l 検知指定文字（複数ある場合はカンマ区切り）`
```
python C:\Users\Administrator\metatrader\MQL5\Scripts\Python\log_monitor\bin\check_log_file.py -d C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Logs -t yesterday -l ERROR,WARN
```