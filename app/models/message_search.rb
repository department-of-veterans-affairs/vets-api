# frozen_string_literal: true

require 'vets/model'

# MessageSearch model
class MessageSearch
  include Vets::Model

  attribute :exact_match, Bool, default: false
  attribute :sender, String
  attribute :subject, String
  attribute :category, String
  attribute :recipient, String
  attribute :from_date, Vets::Type::DateTimeString
  attribute :to_date, Vets::Type::DateTimeString
  attribute :message_id, Integer
end
