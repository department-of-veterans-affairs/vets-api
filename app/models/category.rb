# frozen_string_literal: true

require 'common/models/base'

# Category model
class Category < Common::Base
  def category_id
    0
  end

  attribute :message_category_type, Array

  # Categories are simply an array and have no id.
  def <=>(other)
    category_id <=> other.category_id
  end
end
