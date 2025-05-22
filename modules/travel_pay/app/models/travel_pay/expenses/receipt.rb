# frozen_string_literal: true

require 'active_model'

module TravelPay
  class Receipt
    include ActiveModel::Model

    attr_accessor :file, :description

    # Guess: file could be a path, IO object, or similar
  end
end
