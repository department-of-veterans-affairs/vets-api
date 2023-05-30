# frozen_string_literal: true

require 'vba_documents/pdf_inspector'

module VBADocuments
  class UploadSerializer < ActiveModel::Serializer
    MAX_DETAIL_DISPLAY_LENGTH = 200

    type 'document_upload'

    attributes :guid, :status, :code, :detail, :location, :updated_at, :uploaded_pdf

    module ClassMethods
      include PDFInspector::Constants
      def scrub_unnecessary_keys(pdf_hash)
        pdf_hash.delete(SOURCE_KEY.to_s)
        pdf_hash.delete('submitted_line_of_business')

        if pdf_hash['content'].present?
          pdf_hash['content'].delete('sha256_checksum')
          pdf_hash['content']['attachments']&.each { |attach_hash| attach_hash.delete('sha256_checksum') }
        end

        pdf_hash
      end
    end
    extend ClassMethods

    def id
      object.guid
    end

    delegate :code, to: :object
    delegate :detail, to: :object

    def detail
      detail = object.detail.to_s
      detail = "#{detail[0..MAX_DETAIL_DISPLAY_LENGTH - 1]}..." if detail.length > MAX_DETAIL_DISPLAY_LENGTH
      detail
    end

    def uploaded_pdf
      return nil unless object.uploaded_pdf

      UploadSerializer.scrub_unnecessary_keys(object.uploaded_pdf)
    end

    def status
      object.status == 'vbms' ? 'success' : object.status
    end

    def location
      return nil unless @instance_options[:render_location]

      object.get_location
    rescue => e
      raise Common::Exceptions::InternalServerError, e
    end
  end
end
