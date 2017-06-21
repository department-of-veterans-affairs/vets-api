# frozen_string_literal: true
require 'common/models/base'

# Cemetery model
class Cemetery < Common::Base
  include ActiveModel::Validations

  validates :cemetery_type, inclusion: { in: %w(S N P I A M) }
  validates :name, :num, presence: true

  attribute :cemetery_type, String
  attribute :name, String
  attribute :num, String

  def id
    num
  end

  # Default sort should be by name ascending
  def <=>(other)
    name <=> other.name
  end
end
