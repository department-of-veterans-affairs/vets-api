# frozen_string_literal: true

class HCAAttachmentSerializer
  include JSONAPI::Serializer

  set_type :hca_attachments

  attribute :guid
end
