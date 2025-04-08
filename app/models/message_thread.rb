# frozen_string_literal: true

require 'common/models/base'

class MessageThread < Common::Base
  attribute :thread_id, Integer
  attribute :folder_id, Integer
  attribute :message_id, Integer
  attribute :thread_page_size, Integer
  attribute :message_count, Integer
  attribute :category, String
  attribute :subject, String
  attribute :triage_group_name, String
  attribute :sent_date, Common::UTCTime
  attribute :draft_date, Common::UTCTime
  attribute :sender_id, Integer
  attribute :sender_name, String
  attribute :recipient_name, String
  attribute :recipient_id, Integer
  attribute :proxySender_name, String
  attribute :has_attachment, Boolean
  attribute :thread_has_attachment, Boolean
  attribute :unsent_drafts, Boolean
  attribute :unread_messages, Boolean
  attribute :is_oh_message, Boolean
  attribute :suggested_name_display, String

  def initialize(attributes = {})
    super(attributes)
    self.subject = subject ? Nokogiri::HTML.parse(subject) : nil
  end
end
