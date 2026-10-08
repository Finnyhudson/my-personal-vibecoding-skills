@ECHO off
SETLOCAL
SET "XDG_CONFIG_HOME=C:\Users\hezy15\opencode-v2-trial\config"
SET "XDG_DATA_HOME=C:\Users\hezy15\opencode-v2-trial\data"
SET "XDG_CACHE_HOME=C:\Users\hezy15\opencode-v2-trial\cache"
SET "XDG_STATE_HOME=C:\Users\hezy15\opencode-v2-trial\state"
"C:\Users\hezy15\opencode-v2-trial\node_modules\@opencode\cli\bin\opencode.exe" --standalone %*
