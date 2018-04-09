# frozen_string_literal: true
require 'common/exceptions'

class DocumentUploadSerializer < ActiveModel::Serializer
  type 'document_upload'

  attributes :guid, :status, :location

  def id
    object.guid
  end

  def status
    object.status
  end

  def location
    return nil unless @instance_options[:render_location]
    object.get_location
  rescue StandardError => e
    raise Common::Exceptions::InternalServerError.new(e)
  end
end
