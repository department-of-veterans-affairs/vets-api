require 'nokogiri'
require 'zip'

module TravelPay
  class DocReader
    def initialize(buffer)
      @buffer = buffer
      @doc = read_docx(@buffer)
    end

    def read_docx(buffer)
      doc = nil

      Zip::File.open_buffer(buffer) do |zip_file|
        doc_xml = zip_file.glob('word/document.xml').first.get_input_stream.read
        doc = Nokogiri::XML(doc_xml)
      end

      doc
    rescue Zip::Error => e
      raise "Error reading DOCX file: #{e.message}"
    end

    def find_heading(heading_text)
      # This xpath says: "find any paragraph (w:p) that contains the text '#{heading_text}'"
      match = @doc.xpath(".//w:p[contains(., '#{heading_text}')]")

      # Can't have more than one match and be confident in the result
      return unless match.size == 1

      # Due to poor structure of the doc, we need to check if the paragraph is bold
      # to determine if it is a heading. If not, return.
      # This xpath says: "starting with the current paragraph, find any child that has a bold (w:b) element"
      return if match.first.at_xpath('.//w:b').blank?

      match.first
    end

    def denial_reasons
      heading = find_heading('Denial Reason')

      return unless heading

      # Yeah, yeah, I know.
      # This is due to the poor structure of the DOCX file
      # The template has a structure like this:
      # heading: <w:p>Denial Reason</w:p>
      # .next_sibling: <w:p>NEW_LINE</w:p>
      # .next_sibling: <w:p>Denied for the following reason:</w:p>
      # .next_sibling: <w:p>ACTUAL TEXT</w:p>
      heading.next_sibling.next_sibling.next_sibling.text.strip
    end

    def partial_payment_reasons
      heading = find_heading('Partial Payment Reason')

      return unless heading

      # Hey get off my back.
      # This is due to the poor structure of the DOCX file
      # The template has a structure like this:
      # heading: <w:p>Partial Payment Reason</w:p>
      # .next_sibling: <w:p>NEW_LINE</w:p>
      # .next_sibling: <w:p>Partially paid for the following reason:</w:p>
      # .next_sibling: <w:p>ACTUAL TEXT</w:p>
      heading.next_sibling.next_sibling.next_sibling.text.strip
    end
  end
end
