# frozen_string_literal: true

module EMIS
  module Models
    class Disability
      include Virtus.model

      attribute :disability_percent, Float
      attribute :pay_amount, Float
    end
  end
end
