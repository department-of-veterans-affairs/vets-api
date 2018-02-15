# frozen_string_literal: true

class ProfilePhotoAttachmentSerializer < ActiveModel::Serializer
  attribute :guid
  attribute :filename
  attribute :path

  def filename
    parsed['filename'] if user_uuid.present?
  end

  def path
    parsed['path'] if user_uuid.present?
  end

  private

  def user_uuid
    parsed['user_uuid']
  end

  def parsed
    @parsed ||= JSON.parse(object.file_data)
  end
end
