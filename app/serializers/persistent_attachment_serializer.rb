# frozen_string_literal: true

class PersistentAttachmentSerializer < ActiveModel::Serializer
  attribute :id
  attribute :guid, key: :confirmation_code

  attribute :original_filename, key: :name
  attribute :size
end
