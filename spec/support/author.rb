# frozen_string_literal: true

require 'common/models/base'

class Author < Common::Base
  per_page 20
  max_per_page 1000

  attribute :id, Integer, sortable: { order: 'ASC' }, filterable: %w(eq not_eq)
  attribute :first_name, String, sortable: { order: 'ASC', default: true }, filterable: %w(eq not_eq match)
  attribute :last_name, String, sortable: { order: 'ASC' }, filterable: %w(eq not_eq match)
  attribute :birthdate, Common::UTCTime, sortable: { order: 'DESC' }, filterable: %w(eq lteq gteq not_eq)
  attribute :zipcode, Integer

  def <=>(other)
    first_name <=> other.first_name
  end
end
