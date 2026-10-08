#!/usr/bin/env pwsh
$basedir=Split-Path $MyInvocation.MyCommand.Definition -Parent

if ($MyInvocation.ExpectingInput) {
  $input | & "$basedir/node_modules/opencode-ai/bin/opencode.exe" $args
} else {
  & "$basedir/node_modules/opencode-ai/bin/opencode.exe" $args
}
exit $LASTEXITCODE
