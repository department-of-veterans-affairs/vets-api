# frozen_string_literal: true

module MyHealth
  module V1
    class MessageDetailsSerializer < MessagesSerializer
      include JSONAPI::Serializer

      set_id :message_id

      attribute :message_id, &:id
      attribute :body, &:message_body
      attribute :message_id
      attribute :thread_id
      attribute :folder_id
      attribute :message_body
      attribute :draft_date
      attribute :to_date
      attribute :has_attachments
      attribute :oh_migration_phase
      attribute :attachments do |object|
        Array(object.attachments).map do |att|
          {
            id: att[:attachment_id],
            message_id: object.message_id,
            name: att[:attachment_name],
            attachment_size: att[:attachment_size],
            download: MyHealth::UrlHelper.new.v1_message_attachment_url(object.message_id, att[:attachment_id])
          }
        end
      end

      link :self do |object|
        MyHealth::UrlHelper.new.v1_message_url(object.message_id)
      end
    end
  end
end
