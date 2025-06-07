# frozen_string_literal: true

require 'vets/model'

# Category model
class Category
  include Vets::Model

  def category_id
    0
  end

  attribute :message_category_type, String, array: true, default: []

  # Categories are simply an array and have no id.
  def <=>(other)
    category_id <=> other.category_id
  end
end
