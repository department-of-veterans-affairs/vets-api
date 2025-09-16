# frozen_string_literal: true

class ClaimLetters::DoctypeService
  def self.allowed_for_user(user)
    ClaimLetters::Responses.default_allowed_doctypes(user)
  end
end
