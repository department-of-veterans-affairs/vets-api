# frozen_string_literal: true

# debugger
class PersistentAttachmentVAFormSerializer
  include JSONAPI::Serializer

  attribute :confirmationCode, &:guid
  attribute :name, &:original_filename
  attribute :size
  attribute :warnings
end
