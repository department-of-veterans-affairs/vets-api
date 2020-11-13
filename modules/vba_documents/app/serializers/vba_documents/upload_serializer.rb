# frozen_string_literal: true

require_dependency 'common/exceptions'
require_dependency 'vba_documents/pdf_inspector'

module VBADocuments
  class UploadSerializer < ActiveModel::Serializer
    type 'document_upload'

    attributes :guid, :status, :code, :detail, :location, :updated_at, :uploaded_pdf

    module ClassMethods
      include PDFInspector::Constants
      def scrub_unnecessary_keys(pdf_hash)
        pdf_hash.delete(DOC_TYPE_KEY.to_s)
        pdf_hash.delete(SOURCE_KEY.to_s)
        pdf_hash
      end
    end
    extend ClassMethods

    def id
      object.guid
    end

    delegate :code, to: :object
    delegate :detail, to: :object

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
