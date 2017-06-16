# frozen_string_literal: true
require 'common/models/base'

# PreneedsState model
class PreneedsState < Common::Base
  include ActiveModel::Validations

  validates :code, :first_five_zip, :last_five_zip, :lower_indicator, :name, presence: true

  attribute :code, String, sortable: { order: 'ASC' }, filterable: %w(eq not_eq)
  attribute :name, String, sortable: { order: 'ASC' }, filterable: %w(eq not_eq)
  attribute :first_five_zip, String
  attribute :last_five_zip, String
  attribute :lower_indicator, String

  def id
    code
  end

  # Default sort should be by name ascending
  def <=>(other)
    code <=> other.code
  end
end
