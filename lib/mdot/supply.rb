# frozen_string_literal: true

module MDOT
  class Supply
    include Virtus.model

    attribute :device_name, String, default: ''
    attribute :product_name, String
    attribute :product_group, String
    attribute :product_id, Integer
    attribute :available_for_reorder, Boolean, default: false
    attribute :last_order_date, Date
    attribute :next_availability_date, Date
    attribute :quantity, Integer
    attribute :size, String
    attribute :prescribed_date, Date
  end
end
