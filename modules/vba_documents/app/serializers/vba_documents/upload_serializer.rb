# frozen_string_literal: true

require_dependency 'common/exceptions'
require_dependency 'vba_documents/pdf_inspector'

module VBADocuments
  class UploadSerializer < ActiveModel::Serializer
    type 'document_upload'

    attributes :guid, :status, :code, :detail, :location, :updated_at, :pdf_metadata

    def id
      object.guid
    end

    delegate :code, to: :object
    delegate :detail, to: :object

    def pdf_metadata
      return nil unless object.pdf_metadata
      hash = object.pdf_metadata
      hash.delete(PDFInspector::DOC_TYPE_KEY.to_s)
      hash.delete(PDFInspector::SOURCE_KEY.to_s)
      hash
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
