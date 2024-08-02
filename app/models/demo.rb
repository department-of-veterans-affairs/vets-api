# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  has_many :items, dependent: :destroy

  def gross_price
    items.sum { |item| item.net + item.tax }
  end
end

class Item < ApplicationRecord
  belongs_to :shopping_cart
end
