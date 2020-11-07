# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AppointmentAddress < Common::Resource
      attribute :line1, Types::String
      attribute :line2, Types::String
      attribute :line3, Types::String
      attribute :city, Types::String
      attribute :state, Types::String
      attribute :zip_code, Types::String
    end
  end
end
