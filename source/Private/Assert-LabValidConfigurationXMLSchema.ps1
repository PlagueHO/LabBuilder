<#
    .SYNOPSIS
        Validates the provided configuration XML against the Schema.

    .DESCRIPTION
        This function will ensure that the provided Configration XML
        is compatible with the LabBuilderConfig.xsd Schema file.

    .PARAMETER ConfigPath
        Contains the path to the Configuration XML file.

    .EXAMPLE
        Assert-LabValidConfigurationXMLSchema -ConfigPath c:\mylab\config.xml
        Validates the XML configuration and downloads any resources required by it.

    .OUTPUTS
        None. If the XML is invalid an exception will be thrown.
#>
function Assert-LabValidConfigurationXMLSchema
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ConfigPath
    )

    # Define these variables so they are accesible inside the event handler.
    $script:XMLErrorCount = 0
    $script:XMLFirstError = ''
    $script:XMLPath = $ConfigPath
    $script:ConfigurationXMLValidationMessage = $LocalizedData.ConfigurationXMLValidationMessage

    # Perform the XSD Validation
    $readerSettings = New-Object -TypeName System.Xml.XmlReaderSettings
    $readerSettings.ValidationType = [System.Xml.ValidationType]::Schema
    $null = $readerSettings.Schemas.Add("labbuilderconfig", $script:ConfigurationXMLSchema)
    $readerSettings.ValidationFlags = [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessInlineSchema -bor [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessSchemaLocation
    $readerSettings.add_ValidationEventHandler(
        {
            # Triggered each time an error is found in the XML file
            if ([System.String]::IsNullOrWhitespace($script:XMLFirstError))
            {
                $script:XMLFirstError = $_.Message
            } # if
            Write-LabMessage -Message ($script:ConfigurationXMLValidationMessage `
                    -f $script:XMLPath, $_.Message)
            $script:XMLErrorCount++
        })

    $reader = [System.Xml.XmlReader]::Create([System.String] $ConfigPath, $readerSettings)

    try
    {
        while ($reader.Read())
        {
        } # while
    } # try
    catch
    {
        # XML is NOT valid
        $exceptionParameters = @{
            errorId       = 'ConfigurationXMLValidationError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.ConfigurationXMLValidationError `
                    -f $ConfigPath, $_.Exception.Message)
        }
        New-LabException @exceptionParameters
    } # catch
    finally
    {
        $null = $reader.Close()
    } # finally

    # Verify the results of the XSD validation
    if ($script:XMLErrorCount -gt 0)
    {
        # XML is NOT valid
        $exceptionParameters = @{
            errorId       = 'ConfigurationXMLValidationError'
            errorCategory = 'InvalidArgument'
            errorMessage  = $($LocalizedData.ConfigurationXMLValidationError -f $ConfigPath, $script:XMLFirstError)
        }
        New-LabException @exceptionParameters
    } # if
}
