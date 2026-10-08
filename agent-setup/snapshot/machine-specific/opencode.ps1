#!/usr/bin/env pwsh
$env:XDG_CONFIG_HOME = "C:\Users\hezy15\opencode-v2-trial\config"
$env:XDG_DATA_HOME = "C:\Users\hezy15\opencode-v2-trial\data"
$env:XDG_CACHE_HOME = "C:\Users\hezy15\opencode-v2-trial\cache"
$env:XDG_STATE_HOME = "C:\Users\hezy15\opencode-v2-trial\state"

$binary = "C:\Users\hezy15\opencode-v2-trial\node_modules\@opencode\cli\bin\opencode.exe"

if ($MyInvocation.ExpectingInput) {
  $input | & $binary --standalone @args
} else {
  & $binary --standalone @args
}
exit $LASTEXITCODE
