# frozen_string_literal: true

module ClaimsApi
  module V2
    class MockPdfGeneratorService
      def generate_pdf # rubocop:disable Metrics/MethodLength
        "%PDF-1.7 ' \
        '%\xF6\xE4\xFC\xDF ' \
        '1 0 obj ' \
        '<< ' \
        '/Extensions << ' \
        '/ADBE << ' \
        '/BaseVersion /1.7 ' \
        '/ExtensionLevel 8 ' \
        '>> ' \
        '>> ' \
        '/Lang (en-US) ' \
        '/MarkInfo << ' \
        '/Marked true ' \
        '>> ' \
        '/Metadata 2 0 R ' \
        '/Names 3 0 R ' \
        '/Pages 4 0 R ' \
        '/StructTreeRoot 5 0 R ' \
        '/Type /Catalog ' \
        '/ViewerPreferences << ' \
        '/DisplayDocTitle true ' \
        '>> ' \
        '/Perms 6 0 R ' \
        '>> ' \
        'endobj ' \
        '7 0 obj ' \
        '<< ' \
        '/Author (Y. Allmond) ' \
        '/CreationDate (D:20230111141341-05'00') ' \
        '/Creator (Designer 6.5) ' \
        '/ModDate (D:20230202124244-05'00') ' \
        '/Producer (Designer 6.5) ' \
        '/Subject (APPLICATION FOR DISABILITY COMPENSATION AND RELATED COMPENSATION BENEFITS) ' \
        '/Title (VA Form 21-526EZ) ' \
        '>> ' \
        'endobj ' \
        '2 0 obj ' \
        '<< ' \
        '/Length 5072 ' \
        '/Subtype /XML ' \
        '/Type /Metadata ' \
        '>> ' \
        'stream\r ' \
        '<?xpacket begin=\"\xEF\xBB\xBF\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?> ' \
        '<x:xmpmeta xmlns:x=\"adobe:ns:meta/\" x:xmptk=\"Adobe XMP Core 5.6-c015 81.159809, ' /
        '2016/09/10-01:42:48        \"> ' \
        '   <rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"> ' \
        '      <rdf:Description rdf:about=\"\" ' \
        '            xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\" ' \
        '            xmlns:pdf=\"http://ns.adobe.com/pdf/1.3/\" ' \
        '            xmlns:xmpMM=\"http://ns.adobe.com/xap/1.0/mm/\" ' \
        '            xmlns:dc=\"http://purl.org/dc/elements/1.1/\" ' \
        '            xmlns:pdfuaid=\"http://www.aiim.org/pdfua/ns/id/\" ' \
        '            xmlns:desc=\"http://ns.adobe.com/xfa/promoted-desc/\"> ' \
        '         <xmp:MetadataDate>2023-02-02T12:42:44-05:00</xmp:MetadataDate> ' \
        '         <xmp:CreatorTool>Designer 6.5</xmp:CreatorTool> ' \
        '         <xmp:ModifyDate>2023-02-02T12:42:44-05:00</xmp:ModifyDate> ' \
        '         <xmp:CreateDate>2023-01-11T14:13:41-05:00</xmp:CreateDate> ' \
        '         <pdf:Producer>Designer 6.5</pdf:Producer> ' \
        '         <xmpMM:DocumentID>uuid:092d2693-78f3-4c87-9260-3d0c4e9042da</xmpMM:DocumentID> ' \
        '         <xmpMM:InstanceID>uuid:16b0e147-096e-48a1-93d4-379012b409ce</xmpMM:InstanceID> ' \
        '         <dc:format>application/pdf</dc:format> ' \
        '         <dc:date> ' \
        '            <rdf:Seq> ' \
        '               <rdf:li rdf:parseType=\"Resource\"> ' \
        '                  <rdf:value>11/2022</rdf:value> ' \
        '                  <dc:element-refinement>dc:created</dc:element-refinement> ' \
        '               </rdf:li> ' \
        '               <rdf:li rdf:parseType=\"Resource\"> ' \
        '                  <rdf:value>NOV 2022</rdf:value> ' \
        '                  <dc:element-refinement>dc:issued</dc:element-refinement> ' \
        '               </rdf:li> ' \
        '            </rdf:Seq> ' \
        '         </dc:date> ' \
        '         <dc:description> ' \
        '            <rdf:Alt> ' \
        '               <rdf:li xml:lang=\"x-default\">' \
        'APPLICATION FOR DISABILITY COMPENSATION AND RELATED COMPENSATION BENEFITS</rdf:li> ' \
        '            </rdf:Alt> ' \
        '         </dc:description> ' \
        '         <dc"
      end
    end
  end
end
