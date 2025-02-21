# frozen_string_literal: true

require 'central_mail/utilities'
require 'pdf_info'
require 'pdf_utilities/pdf_validator'
require 'vba_documents/document_request_validator'
require 'vba_documents/multipart_parser'

module VBADocuments
  class PDFInspector
    include CentralMail::Utilities

    attr_accessor :file, :pdf_data, :parts

    module Constants
      SOURCE_KEY = :source
    end
    include Constants

    # If add_file_key is true the file is added to the returned hash as the parent key.
    # Useful for the rake task vba_documents:inspect_pdf
    # pdf can be a String file path or the parts result of 'VBADocuments::MultipartParser.parse(tempfile.path)'
    def initialize(pdf:, add_file_key: false)
      if pdf.is_a?(String)
        raise ArgumentError, "Invalid file #{pdf}, does not exist!" unless File.exist? pdf

        @file = pdf
        @parts = VBADocuments::MultipartParser.parse(@file)
      else
        @parts = pdf
      end
      begin
        @pdf_data = inspect_pdf(add_file_key)
      rescue => e
        Rails.logger.error "Failed to inspect pdf, #{e.message}.", backtrace: e.backtrace
        @pdf_data = { content: { failure: e.message } }
      end
    end

    def to_s
      inspect
    end

    def inspect_pdf(add_file_key)
      parts_metadata = JSON.parse(@parts['metadata'])

      # instantiate the data hash and set the source
      data = { SOURCE_KEY => parts_metadata['source'], total_documents: 0, total_pages: 0, content: {} }

      # read the PDF content
      data[:content].merge!(pdf_metadata(@parts['content']))
      data[:content][:attachments] = []
      add_line_of_business(data, parts_metadata)
      total_pages = data[:content][:page_count]
      total_documents = 1

      # check if this PDF has attachments
      attachment_names = @parts.keys.select { |k| k.match(/attachment\d+/) }

      attachment_names.each do |att|
        attachment_metadata = pdf_metadata(@parts[att])
        total_pages += attachment_metadata[:page_count]
        total_documents += 1
        data[:content][:attachments] << attachment_metadata
      end
      data[:total_documents] = total_documents
      data[:total_pages] = total_pages
      return { @file => data } if add_file_key

      data
    end

    private

    def add_line_of_business(data, parts_metadata)
      if parts_metadata.key? 'businessLine'
        data['line_of_business'] = parts_metadata['businessLine'].to_s.upcase
        data['submitted_line_of_business'] = VALID_LOB[parts_metadata['businessLine'].to_s.upcase]
      end
    end

    def pdf_metadata(pdf)
      metadata = PdfInfo::Metadata.read(pdf)
      max_width, max_height = VBADocuments::DocumentRequestValidator.pdf_validator_options.values_at(
        :width_limit_in_inches, :height_limit_in_inches
      )
      oversized_pages = metadata.oversized_pages_inches(max_width, max_height)

      # report the first oversized page, or if none, use first pages dimensions
      dimensions = oversized_pages.any? ? oversized_pages[0] : metadata.page_size_inches

      {
        page_count: metadata.pages,
        dimensions: {
          height: dimensions[:height].round(2),
          width: dimensions[:width].round(2),
          oversized_pdf: oversized_pages.any?
        },
        file_size: metadata.file_size,
        sha256_checksum: Digest::SHA256.file(pdf).hexdigest
      }
    end
  end
end
