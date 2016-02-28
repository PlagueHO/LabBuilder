<#
.Synopsis
	Creates the ..\schema\labbuilderconfig-schema.md from the ..\schema\labbuilderconfig-schema.xsd
    using the transform\labbuilderconfig-schema-transformtomd.xsl transformation file.
#>
$XMLFile = Join-Path -Path $PSScriptRoot -ChildPath '..\schema\labbuilderconfig-schema.xsd'
$XSLFile = Join-Path -Path $PSScriptRoot -ChildPath 'transform\labbuilderconfig-schema-transformtomd.xsl'
$OutputFile = Join-Path -Path $PSScriptRoot -ChildPath '..\schema\labbuilderconfig-schema.md'
.\Convert-XSDToMD.ps1 `
    -XmlFile $XMLFile `
    -XslFile $XSLFile `
    -OutputFile $OutputFile