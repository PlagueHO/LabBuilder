<#
.Synopsis
	Creates the ..\schema\labbuilderconfig-schema.md from the ..\schema\labbuilderconfig-schema.xsd
    using the transform\labbuilderconfig-schema-transformtomd.xsl transformation file.
#>
$XMLFile = Join-Path -Path $PSScriptRoot -ChildPath '..\schema\labbuilderconfig-schema.xsd'
$XSLFile = Join-Path -Path $PSScriptRoot -ChildPath 'transform\labbuilderconfig-schema-transformtomd.xsl'
$OutputFile = Join-Path -Path $PSScriptRoot -ChildPath '..\docs\labbuilderconfig-schema.md'
Write-Verbose -Verbose "Conversion '..\schema\labbuilderconfig-schema.xsd' to '..\docs\labbuilderconfig-schema.md' started"
& "$PSScriptRoot\Convert-XSDToMD.ps1" `
    -XmlFile $XMLFile `
    -XslFile $XSLFile `
    -OutputFile $OutputFile
Write-Verbose -Verbose "'..\schema\labbuilderconfig-schema.xsd' has been converted to '..\docs\labbuilderconfig-schema.md' successfully"