# frozen_string_literal: true
require 'common/models/base'

# DischargeType model
class DischargeType < Common::Base
  include ActiveModel::Validations

  validates :description, :id, presence: true

  attribute :id, Integer
  attribute :description, String

  # Default sort should be by name ascending
  def <=>(other)
    description <=> other.description
  end
end
