# Runs gitrid in WSL from PowerShell, which picks this file over gitrid.bat.
# A batch file is run through cmd, and cmd drops the ^ from a pattern such as
# ^fix/, which would then match 'hotfix/' as well.
#
# --exec runs the script without a Linux shell in between, so the pattern
# reaches it as typed: $ ( ) | are not read by a shell on the way.
if ($MyInvocation.ExpectingInput) {
    $input | wsl --exec /usr/local/bin/gitrid.sh @args
} else {
    wsl --exec /usr/local/bin/gitrid.sh @args
}
exit $LASTEXITCODE
