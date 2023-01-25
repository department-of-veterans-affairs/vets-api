# frozen_string_literal: true

require 'common/models/base'
require 'common/models/attribute_types/date_time_string'

# MessageSearch model
class MessageSearch < Common::Base
  attribute :exact_match, Boolean
  attribute :sender, String
  attribute :subject, String
  attribute :category, String
  attribute :recipient, String
  attribute :from_date, Common::DateTimeString
  attribute :to_date, Common::DateTimeString
  attribute :message_id, Integer
end
