<#
    .SYNOPSIS
        Sets the Modules Resources that should be imported in a DSC Config.

    .DESCRIPTION
        It will completely replace the list of Imported DSCResources with this new list.

    .PARAMETER DscConfigFile
        Contains the path to the DSC Config file to set resource module names in.

    .PARAMETER DscConfigContent
        Contains the content of the DSC Config to set resource module names in.

    .PARAMETER Modules
        Contains an array of LabDSCModule objects to replace set in the Configuration.

    .EXAMPLE
        Set-LabModulesInDSCConfig -DscConfigFile c:\mydsc\Server01.ps1 -Modules $Modules
        Set the DSC Resource module in the content from file c:\mydsc\server01.ps1

    .EXAMPLE
        Set-LabModulesInDSCConfig -DscConfigContent $DSCConfig -Modules $Modules
        Set the DSC Resource module in the content $DSCConfig

    .OUTPUTS
        A string containing the content of the DSC Config file with the updated
        module names in it.
#>
function Set-LabModulesInDSCConfig
{
    [CmdLetBinding(DefaultParameterSetName = "Content")]
    [OutputType([System.String])]
    param
    (
        [parameter(
            Position = 1,
            ParameterSetName = "Content",
            Mandatory = $true)]
        [System.String]
        $DscConfigContent,

        [parameter(
            Position = 2,
            ParameterSetName = "File",
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DscConfigFile,

        [parameter(
            Position = 3,
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [LabDSCModule[]]
        $Modules
    )

    if ($PSCmdlet.ParameterSetName -eq 'File')
    {
        $DscConfigContent = Get-Content -Path $DscConfigFile -Raw
    } # if

    $regex = "[ \t]*?Import\-DscResource[ \t]+(?:\-ModuleName[ \t]+)?'?`"?([A-Za-z0-9._-]+)`"?'?([ \t]+(-ModuleVersion[ \t]+)?'?`"?([0-9.]+)`"?'?)?[ \t]*[\r\n]+"
    $moduleMatches = [regex]::matches($DscConfigContent, $regex, 'IgnoreCase')

    foreach ($module in $Modules)
    {
        $importCommand = "Import-DscResource -ModuleName '$($module.ModuleName)'"
        if ($module.ModuleVersion)
        {
            $importCommand = "$importCommand -ModuleVersion '$($module.ModuleVersion)'"
        } # if

        $importCommand = "    $importCommand`r`n"

        # is this module already in there?
        $found = $false

        foreach ($moduleMatch in $moduleMatches)
        {
            if ($moduleMatch.Groups[1].Value -eq $module.ModuleName)
            {
                # Found the module - so replace it
                $DscConfigContent = ("{0}{1}{2}" -f `
                        $DscConfigContent.Substring(0, $moduleMatch.Index), `
                        $importCommand, `
                        $DscConfigContent.Substring($moduleMatch.Index + $moduleMatch.Length))

                $moduleMatches = [regex]::matches($DscConfigContent, $regex, 'IgnoreCase')
                $found = $true
                break
            } # if
        } # foreach

        if (-not $found)
        {
            if ($moduleMatches.Count -gt 0)
            {
                # Add this to the end of the existing Import-DSCResource lines
                $moduleMatch = $moduleMatches[$moduleMatches.count - 1]
            }
            else
            {
                # There are no existing DSC Resource lines, so add it after
                # Configuration ... { line
                $moduleMatch = [regex]::matches($DscConfigContent, "[ \t]*?Configuration[ \t]+?'?`"?[A-Za-z0-9._-]+`"?'?[ \t]*?[\r\n]*?{[\r\n]*?", 'IgnoreCase')

                if (-not $moduleMatch)
                {
                    $exceptionParameters = @{
                        errorId       = 'DSCConfiguartionMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage  = $($LocalizedData.DSCConfiguartionMissingError)
                    }
                    New-LabException @exceptionParameters
                }
            } # if

            $DscConfigContent = ("{0}{1}{2}" -f `
                    $DscConfigContent.Substring(0, $moduleMatch.Index + $moduleMatch.Length), `
                    $importCommand, `
                    $DscConfigContent.Substring($moduleMatch.Index + $moduleMatch.Length))

            $moduleMatches = [regex]::matches($DscConfigContent, $regex, 'IgnoreCase')
        } # Module not found so add it to the end
    } # foreach

    return $DscConfigContent
}
