# frozen_string_literal: true

module MyHealth
  module V1
    class ThreadsSerializer < ActiveModel::Serializer
      def id
        object.thread_id
      end

      attribute :thread_id
      attribute :folder_id
      attribute :message_id
      attribute :thread_page_size
      attribute :message_count
      attribute :category
      attribute :subject
      attribute :triage_group_name
      attribute :sent_date
      attribute :draft_date
      attribute :sender_id
      attribute :sender_name
      attribute :recipient_name
      attribute :recipient_id
      attribute :proxySender_name
      attribute :has_attachment
      attribute :unsent_drafts
      attribute :unread_messages

      link(:self) { MyHealth::UrlHelper.new.v1_thread_url(object.thread_id) }
    end
  end
end
