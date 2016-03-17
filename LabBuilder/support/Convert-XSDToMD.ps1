<#
.Synopsis
	Uses the MSXSL.EXE to apply an XML Stylesheet Transformation to an XML file.
.Parameter XmlFile
	The full path to the XML file to transform.
.Parameter XslFile
	The full path to the XSLT file to use as the transformation.
.Parameter OutputFile
	The full path to the output file to create.
#>
param
(
    [String]
    $XmlFile,
    
    [String]
    $XslFile,
    
    [String]
    $OutputFile
)
& "$PSScriptRoot\tools\msxsl.exe" @($XmlFile,$XslFile,'-o',$OutputFile)
$content = Get-Content -Raw -Encoding Unicode -Path $OutputFile
[System.IO.File]::WriteAllText($OutputFile, $content, [System.Text.Encoding]::UTF8)
