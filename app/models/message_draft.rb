# frozen_string_literal: true

# Message drafts are essentially messages with an implied folder (drafts)
class MessageDraft < Message
  alias_attribute :draft_id, :id
end
