# frozen_string_literal: true

require 'common/models/base'

module VeteranVerification
    class Rating
      include ActiveModel::Serialization
      include Virtus.model

      attribute :decision, String
      attribute :effective_date, Date
      attribute :rating_percentage, String
    end
end
