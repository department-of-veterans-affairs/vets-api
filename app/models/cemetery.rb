# frozen_string_literal: true
require 'common/models/base'

# Cemetery model
class Cemetery < Common::Base
  include ActiveModel::Validations

  # Cemetery numbers are 3-digits, implying < 1000 in total - we want all of them for populating application forms
  per_page 1000
  max_per_page 1000

  validates :cemetery_type, inclusion: { in: %w(S N P I A M) }
  validates :name, :num, presence: true

  attribute :cemetery_type, String, filterable: %w(eq not_eq)
  attribute :name, String, sortable: { order: 'ASC' }, filterable: %w(eq not_eq)
  attribute :num, String, sortable: { order: 'ASC' }, filterable: %w(eq not_eq)

  def id
    num
  end

  # Default sort should be by name ascending
  def <=>(other)
    name <=> other.name
  end
end
