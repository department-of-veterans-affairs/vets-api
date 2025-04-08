# frozen_string_literal: true

class RepresentativeAttachmentFormSerializer
  include JSONAPI::Serializer

  attribute :confirmationCode, &:guid
  attribute :name, &:original_filename
  attribute :size
  attribute :warnings
end
