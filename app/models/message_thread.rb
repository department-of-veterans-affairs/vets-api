# frozen_string_literal: true

require 'vets/model'

class MessageThread
  include Vets::Model
  attribute :thread_id, Integer
  attribute :folder_id, Integer
  attribute :message_id, Integer
  attribute :thread_page_size, Integer
  attribute :message_count, Integer
  attribute :category, String
  attribute :subject, String
  attribute :triage_group_name, String
  attribute :sent_date, Vets::Type::UTCTime
  attribute :draft_date, Vets::Type::UTCTime
  attribute :sender_id, Integer
  attribute :sender_name, String
  attribute :recipient_name, String
  attribute :recipient_id, Integer
  attribute :proxySender_name, String
  attribute :has_attachment, Bool, default: false
  attribute :thread_has_attachment, Bool, default: false
  attribute :unsent_drafts, Bool, default: false
  attribute :unread_messages, Bool, default: false
  attribute :is_oh_message, Bool, default: false
  attribute :suggested_name_display, String

  def initialize(attributes = {})
    super(attributes)
    @subject = subject ? Nokogiri::HTML.parse(subject).text : nil
  end
end
