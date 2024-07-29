# frozen_string_literal: true

module MyHealth
  module V1
    class AttachmentSerializer
      include JSONAPI::Serializer

      set_type :attachments

      attribute :name
      attribute :message_id
      attribute :attachment_size

      link :download do |object|
        MyHealth::UrlHelper.new.v1_message_attachment_url(object.message_id, object.id)
      end
    end
  end
end
