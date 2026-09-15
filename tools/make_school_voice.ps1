$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskVoice = New-Object -ComObject SAPI.SpVoice
$taskVoice.Voice = $taskVoice.GetVoices() | Where-Object { $_.GetDescription() -like '*Huihui*' } | Select-Object -First 1
$taskVoice.Rate = -1
$taskLines = @(
 '全体同学请注意。全体同学请注意。',
 '这里是学校广播站。',
 '毛主席教导我们，好好学习，天天向上。',
 '今天的课程已经结束。',
 '请各班按照早上的点名册清点人数，结伴离校。',
 '值日同学打扫教室，关好门窗。',
 '明天照常上课。',
 '本次广播到此结束。'
)
for ($taskIndex=0; $taskIndex -lt $taskLines.Count; $taskIndex++) {
 $taskStream = New-Object -ComObject SAPI.SpFileStream
 $taskStream.Format.Type = 22
 $taskStream.Open((Join-Path $taskRoot ('assets/audio/broadcast/voice-{0}.wav' -f $taskIndex)),3,$false)
 $taskVoice.AudioOutputStream = $taskStream
 $taskVoice.Speak($taskLines[$taskIndex]) | Out-Null
 $taskStream.Close()
}
$taskLines | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRoot 'assets/audio/broadcast/lines.json') -Encoding utf8
