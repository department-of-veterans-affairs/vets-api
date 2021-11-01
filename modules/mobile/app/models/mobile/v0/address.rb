# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # @example create a new instance and parse incoming data
    #   Mobile::V0::Adapters::Address.new(address_hash)
    #
    class Address < Common::Resource
      attribute :street, Types::String
      attribute :city, Types::String
      attribute :state, Types::String
      attribute :zip_code, Types::String
    end
  end
end
