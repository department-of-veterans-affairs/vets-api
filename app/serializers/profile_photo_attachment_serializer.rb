# frozen_string_literal: true

class ProfilePhotoAttachmentSerializer < ActiveModel::Serializer
  attribute :guid
  attribute :filename
  attribute :path

  def filename
    parsed['filename']
  end

  def path
    parsed['path']
  end

  def parsed
    @parsed ||= JSON.parse(object.file_data)
  end
end
