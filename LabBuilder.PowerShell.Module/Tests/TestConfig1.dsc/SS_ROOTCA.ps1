Configuration SS_ROOTCA
{
   Node "SS_ROOTCA"
   {
      WindowsFeature ADCS
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "ADCS-Cert-Authority"  
      }
   }
} 