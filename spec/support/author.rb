# frozen_string_literal: true

require 'vets/model'

class Author
  include Vets::Model
  per_page 20
  max_per_page 1000

  attribute :id, Integer, filterable: %w[eq not_eq]
  attribute :first_name, String, filterable: %w[eq not_eq match]
  attribute :last_name, String, filterable: %w[eq not_eq match]
  attribute :birthdate, Vets::Type::UTCTime, filterable: %w[eq lteq gteq not_eq]
  attribute :zipcode, Integer

  default_sort_by id: :asc
  default_sort_by first_name: :asc
  default_sort_by last_name: :asc
  default_sort_by birthdate: :desc

  def <=>(other)
    first_name <=> other.first_name
  end
end
