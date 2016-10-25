# frozen_string_literal: true

# Message drafts are essentially messages with an implied folder (drafts), and if a reply an implied message
class MessageDraft < Message
  validate :check_as_replydraft, if: proc { reply? }
  validate :check_as_draft, unless: proc { reply? }

  attribute :has_message, Boolean

  def message?
    has_message
  end

  private

  def check_as_replydraft
    errors[:base] << 'This draft requires a reply-to message.' unless message?
  end

  def check_as_draft
    errors[:base] << 'This draft cannot have a reply-to message' if message?
  end
end
