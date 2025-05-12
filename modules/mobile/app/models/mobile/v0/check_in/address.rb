# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module CheckIn
      class Address < Common::Resource
        attribute :street1, Types::String
        attribute :street2, Types::String
        attribute :street3, Types::String
        attribute :city, Types::String
        attribute :county, Types::String
        attribute :state, Types::String
        attribute :zip, Types::String
        attribute :zip4, Types::String
        attribute :country, Types::String
      end
    end
  end
end
