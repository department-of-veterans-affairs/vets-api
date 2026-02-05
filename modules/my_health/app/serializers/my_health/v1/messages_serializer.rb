# frozen_string_literal: true

module MyHealth
  module V1
    class MessagesSerializer
      include JSONAPI::Serializer

      attribute :message_id, &:id
      attribute :category
      attribute :subject
      attribute :body
      attribute :attachment
      attribute :sent_date
      attribute :sender_id
      attribute :sender_name
      attribute :recipient_id
      attribute :recipient_name
      attribute :read_receipt
      attribute :triage_group_name
      attribute :proxy_sender_name
      attribute :suggested_name_display
      attribute :is_oh_message
      attribute :oh_migration_phase

      link :self do |object|
        MyHealth::UrlHelper.new.v1_message_url(object.id)
      end
    end
  end
end
