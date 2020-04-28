# frozen_string_literal: true

require 'common/models/base'

module VeteranVerification
    class Rating
      include Virtus.model

      attribute :decision
      attribute :end_date
      attribute :rating_percentage
    end
end
