# frozen_string_literal: true
require 'common/models/base'
class DisabilityRating < Common::Base
  attribute :ratings, Array
  attribute :service_connected_combined_degree, String
end
