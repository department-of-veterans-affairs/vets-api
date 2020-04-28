# frozen_string_literal: true

require 'common/models/base'

module VeteranVerification
    class DisabilityRatingRecord
      include Virtus.model

      attribute :service_connected_combined_degree, Integer
    end
end

