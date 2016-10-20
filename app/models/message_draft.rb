# frozen_string_literal: true

# Message drafts are essentially messages with an implied folder (drafts), and if a reply an implied message
class MessageDraft < Message
  validate :check_as_reply_draft, if: proc { replydraft? }
  validate :check_as_draft, unless: proc { replydraft? }

  attribute :has_message, Boolean

  def message?
    has_message
  end

  private

  def check_as_reply_draft
    errors[:base] << 'Draft cannot be treated as a reply draft.' unless message?
  end

  def check_as_draft
    errors[:base] << 'Reply draft cannot be treated as draft' if message?
  end
end
