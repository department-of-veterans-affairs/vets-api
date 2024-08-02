# frozen_string_literal: true

class ShoppingCart < ActiveRecord::Base
  has_many :items

  def gross_price
    items.sum { |item| item.net + item.tax }
  end
end

class Item < ActiveRecord::Base
  belongs_to :shopping_cart
end
