# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AppointmentAddress < Common::Resource
      attribute :street, Types::String
      attribute :city, Types::String
      attribute :state, Types::String
      attribute :zip_code, Types::String
    end
  end
end
