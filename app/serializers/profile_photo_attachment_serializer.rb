# frozen_string_literal: true

class ProfilePhotoAttachmentSerializer < ActiveModel::Serializer
  attribute :guid
  attribute :filename
  attribute :path

  def filename
    parsed['filename'] unless @instance_options[:is_anonymous_upload]
  end

  def path
    parsed['path'] unless @instance_options[:is_anonymous_upload]
  end

  private

  def parsed
    @parsed ||= JSON.parse(object.file_data)
  end
end
