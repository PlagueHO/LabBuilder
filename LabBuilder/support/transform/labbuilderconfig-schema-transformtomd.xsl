<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema">
<xsl:output method="text" omit-xml-declaration="yes" indent="no"/>
<xsl:template match="/">
# LabBuilder Configuration XML File Format
> labbuilderconfig xmlns="labbuilderconfig"
<xsl:for-each select="xs:schema/xs:element/xs:complexType">
<xsl:for-each select="xs:attribute">
### <xsl:value-of select="translate(@name,
                                'abcdefghijklmnopqrstuvwxyz',
                                'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/> Attribute
> <xsl:if test="@use='required'">**</xsl:if><xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:if test="@use='required'"> (required)**</xsl:if><xsl:text>&#13;&#10;&#13;&#10;</xsl:text>
<xsl:value-of select="normalize-space(xs:annotation/xs:documentation)"/><xsl:text>&#13;&#10;</xsl:text>
</xsl:for-each>
<xsl:for-each select="xs:all/xs:element">
### <xsl:value-of select="translate(@name,
                                'abcdefghijklmnopqrstuvwxyz',
                                'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/> Element
> <xsl:if test="@use='required'">**</xsl:if><xsl:value-of select="@name"/>="<xsl:value-of select="@type"/>"<xsl:if test="@use='required'"> (required)**</xsl:if><xsl:text>&#13;&#10;&#13;&#10;</xsl:text>
<xsl:value-of select="normalize-space(xs:annotation/xs:documentation)"/><xsl:text>&#13;&#10;</xsl:text>
</xsl:for-each>
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>