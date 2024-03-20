# frozen_string_literal: true

require 'common/models/base'

module TravelPay
  class Claim < Common::Base
    include ActiveModel::Serializers::JSON

    # will likely be a UUID
    attribute :id, String 

    def initialize(id)
      self.id = id
    end
  end
end

