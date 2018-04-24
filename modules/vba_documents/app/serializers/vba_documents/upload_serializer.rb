# frozen_string_literal: true

require_dependency 'common/exceptions'

module VBADocuments
  class UploadSerializer < ActiveModel::Serializer
    type 'document_upload'

    attributes :guid, :status, :code, :detail, :location

    def id
      object.guid
    end

    delegate :status, to: :object
    delegate :code, to: :object
    delegate :detail, to: :object

    def location
      return nil unless @instance_options[:render_location]
      object.get_location
    rescue StandardError => e
      raise Common::Exceptions::InternalServerError, e
    end
  end
end
