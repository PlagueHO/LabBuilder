Configuration SS_ROOTCA
{
   Import-DscResource –ModuleName ’PSDesiredStateConfiguration’
   Node "SS_ROOTCA"
   {
      WindowsFeature ADCS-Cert-Authority
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "ADCS-Cert-Authority"  
      }
   }
}
