param
(
    [String] $XmlFile,
    
    [String] $XslFile
)

[String] $TransformedXML
[String] $Output = ''
$xslt = New-Object System.Xml.Xsl.XslCompiledTransform
$xslt.Load($XslFile)
$xslt.Transform($XmlFile, $output)
return $Output
