<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema">
<xsl:output method="text" omit-xml-declaration="yes" indent="no"/>
<xsl:variable name="Title1" select="1" />
<xsl:variable name="Title2" select="1" />
<xsl:variable name="Title3" select="1" />
<xsl:variable name="Title4" select="1" />
<xsl:variable name="Title5" select="1" />
<xsl:template match="/">
# LabBuilder Configuration XML File Format
> labbuilderconfig xmlns="labbuilderconfig"
  <xsl:for-each select="xs:schema/xs:element/xs:complexType">
    <xsl:for-each select="xs:attribute">
      <xsl:variable name="Title1" select="position()" />
### <xsl:value-of select="$Title1"/>.0a - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="@use='required'"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Attribute
> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text>
      <xsl:for-each select="xs:annotation">
        <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
        <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
      </xsl:for-each>
    </xsl:for-each>
    <xsl:for-each select="xs:all/xs:element|xs:sequence/xs:element">
      <xsl:variable name="Title1" select="position()" />
### <xsl:value-of select="$Title1"/>.0e - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="number(@minOccurs)>0"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Element
<xsl:choose><xsl:when test="@type"><xsl:text>&#13;&#10;</xsl:text>> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text></xsl:when><xsl:otherwise></xsl:otherwise></xsl:choose>
      <xsl:for-each select="xs:annotation">
        <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
        <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
      </xsl:for-each>
      <xsl:for-each select="xs:complexType/xs:attribute">
        <xsl:variable name="Title2" select="position()" />
### <xsl:value-of select="$Title1"/>.<xsl:value-of select="$Title2"/>a - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="@use='required'"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Attribute
> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text>
        <xsl:for-each select="xs:annotation">
          <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
          <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
        </xsl:for-each>
      </xsl:for-each>
      <xsl:for-each select="xs:complexType/xs:all/xs:element|xs:complexType/xs:sequence/xs:element">
        <xsl:variable name="Title2" select="position()" />
### <xsl:value-of select="$Title1"/>.<xsl:value-of select="$Title2"/>e - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="number(@minOccurs)>0"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Element
<xsl:choose><xsl:when test="@type"><xsl:text>&#13;&#10;</xsl:text>> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text></xsl:when><xsl:otherwise></xsl:otherwise></xsl:choose>
        <xsl:for-each select="xs:annotation">
          <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
          <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
        </xsl:for-each>
        <xsl:for-each select="xs:complexType/xs:attribute">
          <xsl:variable name="Title3" select="position()" />
### <xsl:value-of select="$Title1"/>.<xsl:value-of select="$Title2"/>.<xsl:value-of select="$Title3"/>a - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="@use='required'"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Attribute
> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text>
          <xsl:for-each select="xs:annotation">
            <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
            <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
          </xsl:for-each>
        </xsl:for-each>
        <xsl:for-each select="xs:complexType/xs:all/xs:element|xs:complexType/xs:sequence/xs:element">
          <xsl:variable name="Title3" select="position()" />
### <xsl:value-of select="$Title1"/>.<xsl:value-of select="$Title2"/>.<xsl:value-of select="$Title3"/>e - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="number(@minOccurs)>0"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Element
<xsl:choose><xsl:when test="@type"><xsl:text>&#13;&#10;</xsl:text>> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text></xsl:when><xsl:otherwise></xsl:otherwise></xsl:choose>
          <xsl:for-each select="xs:annotation">
            <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
            <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
          </xsl:for-each>
          <xsl:for-each select="xs:complexType/xs:attribute">
            <xsl:variable name="Title4" select="position()" />
### <xsl:value-of select="$Title1"/>.<xsl:value-of select="$Title2"/>.<xsl:value-of select="$Title3"/>.<xsl:value-of select="$Title4"/>a - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="@use='required'"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Attribute
> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text>
            <xsl:for-each select="xs:annotation">
              <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
              <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
            </xsl:for-each>
          </xsl:for-each>
          <xsl:for-each select="xs:complexType/xs:all/xs:element|xs:complexType/xs:sequence/xs:element">
            <xsl:variable name="Title4" select="position()" />
### <xsl:value-of select="$Title1"/>.<xsl:value-of select="$Title2"/>.<xsl:value-of select="$Title3"/>.<xsl:value-of select="$Title4"/>e - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="number(@minOccurs)>0"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Element
<xsl:choose><xsl:when test="@type"><xsl:text>&#13;&#10;</xsl:text>> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text></xsl:when><xsl:otherwise></xsl:otherwise></xsl:choose>
            <xsl:for-each select="xs:annotation">
              <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
              <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
            </xsl:for-each>
            <xsl:for-each select="xs:complexType/xs:attribute">
              <xsl:variable name="Title5" select="position()" />
### <xsl:value-of select="$Title1"/>.<xsl:value-of select="$Title2"/>.<xsl:value-of select="$Title3"/>.<xsl:value-of select="$Title4"/>.<xsl:value-of select="$Title5"/>a - <xsl:value-of select="translate(@name,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:choose><xsl:when test="@use='required'"> Required</xsl:when><xsl:otherwise> Optional</xsl:otherwise></xsl:choose> Attribute
> <xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:text>&#13;&#10;&#13;&#10;</xsl:text>
              <xsl:for-each select="xs:annotation">
                <xsl:for-each select="xs:documentation"><xsl:value-of select="."/><xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
                <xsl:for-each select="xs:appinfo">``` <xsl:value-of select="."/> ```<xsl:text>&#13;&#10;</xsl:text></xsl:for-each>
              </xsl:for-each>
            </xsl:for-each>
          </xsl:for-each>
        </xsl:for-each>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:for-each>
</xsl:template>
</xsl:stylesheet>