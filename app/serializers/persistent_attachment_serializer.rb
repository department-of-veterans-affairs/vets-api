# frozen_string_literal: true

class PersistentAttachmentSerializer
  include JSONAPI::Serializer

  attribute :confirmation_code, &:guid
  attribute :name, &:original_filename
  attribute :size
end
