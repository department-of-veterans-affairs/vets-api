# frozen_string_literal: true

module Pensions
  class PersistentAttachment < ::PersistentAttachment
    self.inheritance_column = :_type_disabled
    belongs_to :saved_claim, inverse_of: :persistent_attachments, optional: true
  end
end
