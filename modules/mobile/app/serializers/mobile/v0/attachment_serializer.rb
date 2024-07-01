# frozen_string_literal: true

module Mobile
  module V0
    class AttachmentSerializer
      include JSONAPI::Serializer

      set_id :id
      set_type :attachments

      attributes :name, :message_id

      attribute :attachment_size, if: proc { |object| object.attachment_size&.positive? }

      link :download do |object|
        Mobile::UrlHelper.new.v0_message_attachment_url(object.message_id, object.id)
      end
    end
  end
end
