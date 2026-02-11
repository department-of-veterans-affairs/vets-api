# frozen_string_literal: true

module Mobile
  module V1
    class MessagesSerializer
      include JSONAPI::Serializer

      set_id :message_id
      set_type :message_thread_details

      attributes :message_id, :body, :category, :subject, :message_body, :attachment, :sent_date,
                 :sender_id, :sender_name, :recipient_id, :recipient_name, :read_receipt,
                 :triage_group_name, :proxy_sender_name, :thread_id, :folder_id,
                 :draft_date, :to_date, :has_attachments, :reply_disabled

      attribute :body, &:message_body

      link :self do |object|
        Mobile::UrlHelper.new.v0_message_url(object.message_id)
      end
    end
  end
end
