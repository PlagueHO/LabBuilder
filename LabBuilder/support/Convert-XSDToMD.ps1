param
(
    [String] $XmlFile,
    
    [String] $XslFile,
    
    [String] $OutputFile
)
& .\tools\msxml.exe @($XmlFile,$XslFile,'-o',$OutputFile)
