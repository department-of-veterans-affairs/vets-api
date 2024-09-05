# frozen_string_literal: true

class PreneedAttachmentSerializer
  include JSONAPI::Serializer

  set_type :preneeds_preneed_attachments

  attribute :guid
end
