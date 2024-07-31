# frozen_string_literal: true

module Form1010cg
  class AttachmentSerializer
    include JSONAPI::Serializer

    set_type :form1010cg_attachments

    attribute :guid
  end
end
