# frozen_string_literal: true

module MyHealth
  module V1
    class MessageDetailsSerializer < MessagesSerializer
      def id
        object.message_id
      end

      def body
        object.message_body
      end

      attribute :message_id
      attribute :thread_id
      attribute :folder_id
      attribute :message_body
      attribute :draft_date
      attribute :to_date
      attribute :has_attachments

      link(:self) { MyHealth::UrlHelper.new.v1_message_url(object.message_id) }
    end
  end
end
