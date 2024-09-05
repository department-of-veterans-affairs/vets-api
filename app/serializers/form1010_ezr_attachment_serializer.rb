# frozen_string_literal: true

class Form1010EzrAttachmentSerializer
  include JSONAPI::Serializer

  set_type :form1010_ezr_attachments

  attribute :guid
end
