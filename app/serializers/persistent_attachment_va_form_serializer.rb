# frozen_string_literal: true

class PersistentAttachmentVAFormSerializer
  include JSONAPI::Serializer

  attribute :confirmation_code, &:guid
  attribute :name, &:original_filename
  attribute :size
  attribute :warnings
end
