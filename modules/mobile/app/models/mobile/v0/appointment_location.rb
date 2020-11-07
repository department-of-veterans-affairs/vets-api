# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AppointmentLocation < Common::Resource
      attribute :name, Types::String
      attribute :address, Types::String
      attribute :phone, Types::String
      attribute :url, Types::String
      attribute :code, Types::String
    end
  end
end
