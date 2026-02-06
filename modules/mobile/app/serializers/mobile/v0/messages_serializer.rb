# frozen_string_literal: true

module Mobile
  module V0
    class MessagesSerializer
      include JSONAPI::Serializer

      set_id :id
      set_type :messages

      attributes :category, :subject, :body, :attachment, :sent_date,
                 :sender_id, :sender_name, :recipient_id, :recipient_name, :read_receipt,
                 :triage_group_name, :proxy_sender_name, :is_oh_message, :oh_migration_phase

      attribute :message_id, &:id

      link :self do |object|
        Mobile::UrlHelper.new.v0_message_url(object.id)
      end
    end
  end
end
