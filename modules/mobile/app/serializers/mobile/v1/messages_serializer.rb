# frozen_string_literal: true

module Mobile
  module V1
    class MessagesSerializer < ActiveModel::Serializer
      def id
        object.message_id
      end

      def body
        object.message_body
      end

      def attachment
        object.has_attachments
      end

      attribute :message_id
      attribute :body
      attribute :category
      attribute :subject
      attribute :message_body
      attribute :attachment
      attribute :sent_date
      attribute :sender_id
      attribute :sender_name
      attribute :recipient_id
      attribute :recipient_name
      attribute :read_receipt
      attribute :triage_group_name
      attribute :proxy_sender_name
      attribute :thread_id
      attribute :folder_id
      attribute :draft_date
      attribute :to_date

      link(:self) { Mobile::UrlHelper.new.v0_message_url(object.message_id) }
    end
  end
end
