# frozen_string_literal: true
require 'common/models/base'

# Message model
class Message < Common::Base
  include ActiveModel::Validations

  validates :body, presence: true

  attribute :id, Integer
  attribute :category, String
  attribute :subject, String
  attribute :body, String
  attribute :attachment, Boolean
  attribute :sent_date, Common::UTCTime
  attribute :sender_id, Integer
  attribute :sender_name, String
  attribute :recipient_id, Integer
  attribute :recipient_name, String
  attribute :read_receipt, String

  alias attachment? attachment

  def <=>(other)
    id <=> other.id
  end
end
