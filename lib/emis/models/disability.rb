# frozen_string_literal: true

module EMIS
  module Models
    # EMIS veteran disability pay data
    # @!attribute disability_percent
    #   @return [Float] code that represents the rating of percentage of disability.
    # @!attribute pay_amount
    #   @return [Float] amount of pay the veteran receives for the disability.
    class Disability
      include Virtus.model

      attribute :disability_percent, Float
      attribute :pay_amount, Float

      %w[disability_percent pay_amount].each do |attr|
        define_method("get_#{attr}") do
          public_send(attr) || 0
        end
      end
    end
  end
end
