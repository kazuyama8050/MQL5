setlocal
set app_dir=C:\\Users|Administrator\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5
set project_dir=C:\\Users|Administrator\metatrader\MQL5

mklink /d %project_dir%\Experts\MyExperts %app_dir%\Experts\MyExperts
mklink /d %project_dir%\Include\MyInclude %app_dir%\Include\MyInclude
mklink /d %project_dir%\Libraries\MyLibraries %app_dir%\Libraries\MyLibraries
mklink /d %project_dir%\Scripts\Python %app_dir%\Scripts\Python
mklink /d %app_dir%\Files\Logs %app_dir%\Logs