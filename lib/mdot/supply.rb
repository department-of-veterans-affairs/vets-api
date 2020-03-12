# frozen_string_literal: true

module MDOT
  class Supply
    include Virtus.model

    attribute :device_name, String
    attribute :product_name, String
    attribute :product_group, String
    attribute :product_id, String
    attribute :available_for_reorder, Boolean, default: false
    attribute :last_order_date, DateTime
    attribute :next_availability_date, DateTime
    attribute :quantity, Integer
  end
end
