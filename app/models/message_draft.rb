# frozen_string_literal: true

##
# Models Message draft
# @note drafts are essentially messages with an implied folder (drafts), and if a reply, an implied message
#
# @!attribute has_message
#   @return [Boolean]
#
class MessageDraft < Message
  validate :check_as_replydraft, if: proc { reply? }
  validate :check_as_draft, unless: proc { reply? }
  attr_accessor :original_attributes

  attribute :has_message, Boolean

  def message?
    has_message
  end

  private

  def check_as_replydraft
    errors.add(:base, 'This draft requires a reply-to message.') unless message?
  end

  def check_as_draft
    errors.add(:base, 'This draft cannot have a reply-to message') if message?
  end
end
