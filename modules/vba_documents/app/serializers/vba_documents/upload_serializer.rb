# frozen_string_literal: true

require 'vba_documents/pdf_inspector'

module VBADocuments
  class UploadSerializer
    include JSONAPI::Serializer

    MAX_DETAIL_DISPLAY_LENGTH = 200

    set_type :document_upload
    set_id :guid

    attributes :guid, :status, :code

    attribute :detail do |object|
      detail = object.detail.to_s
      detail.length > MAX_DETAIL_DISPLAY_LENGTH ? "#{detail[0..MAX_DETAIL_DISPLAY_LENGTH - 1]}..." : detail
    end

    attribute :location do |object, params|
      object.get_location if params[:render_location]
    rescue => e
      raise Common::Exceptions::InternalServerError, e
    end

    attribute :updated_at

    attribute :uploaded_pdf do |object|
      scrub_unnecessary_keys(object.uploaded_pdf) if object.uploaded_pdf
    end

    def self.scrub_unnecessary_keys(pdf_hash)
      pdf_hash.delete(PDFInspector::Constants::SOURCE_KEY.to_s)
      pdf_hash.delete('submitted_line_of_business')

      if pdf_hash['content'].present?
        pdf_hash['content'].delete('sha256_checksum')
        pdf_hash['content']['attachments']&.each { |attach_hash| attach_hash.delete('sha256_checksum') }
      end

      pdf_hash
    end
  end
end
