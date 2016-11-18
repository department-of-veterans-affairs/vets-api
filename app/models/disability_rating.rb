# frozen_string_literal: true
require 'common/models/base'
class DisabilityRating < Common::Base
  attribute :ratings, Array
  attribute :serviceConnectedCombinedDegree, String
end
