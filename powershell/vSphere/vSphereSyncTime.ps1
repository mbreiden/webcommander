<#
Copyright (c) 2012-2014 VMware, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

## Author: Jerry Liu, liuj@vmware.com

Param (
	$serverAddress, 
	$serverUser="root", 
	$serverPassword=$env:defaultPassword, 
	$ntpServerAddress="10.132.71.1"
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

add-pssnapin vmware.vimautomation.core -ea silentlycontinue

try {
	connect-VIServer $serverAddress -user $serverUser -password $serverPassword -wa 0 -EA stop
} catch {
	writeCustomizedMsg "Fail - connect to server $address"
	writeStderr
	[Environment]::exit("0")
}

get-vmhost | % {
	try {
		$_ | add-vmhostNtpServer $ntpServerAddress -ea SilentlyContinue
		$_ | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true
		$_ | Get-VmHostService | ? {$_.key -eq "ntpd"} | Start-VMHostService
		$_ | Get-VmHostService | ? {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic"
	} catch {
		writeCustomizedMsg "Fail - configure NTP settings for vmhost $($_.name)"
		writeStderr
		#[Environment]::exit("0")
	}
	writeCustomizedMsg "Success - configure NTP settings for vmhost $($_.name)"
}

get-vm | % {
	try {
		$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
		$spec.changeVersion = $_.ExtensionData.Config.ChangeVersion
		$spec.tools = New-Object VMware.Vim.ToolsConfigInfo
		$spec.tools.syncTimeWithHost = $true
		$_this = Get-View -Id $_.Id
		$_this.ReconfigVM_Task($spec)
	} catch {
		writeCustomizedMsg "Fail - configure time sync settings for vm $($_.name)"
		writeStderr
		#[Environment]::exit("0")
	}
	writeCustomizedMsg "Success - configure time sync settings for vm $($_.name)"
}

disconnect-VIServer -Server * -Force -Confirm:$false