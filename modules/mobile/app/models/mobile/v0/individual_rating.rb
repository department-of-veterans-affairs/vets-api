# frozen_string_literal: true

require 'vets/model'

module Mobile
  module V0
    class IndividualRating
      include Vets::Model

      attribute :decision, String
      attribute :effective_date, DateTime
      attribute :rating_percentage, Integer
      attribute :diagnostic_text, String
    end
  end
end
