# frozen_string_literal: true

p # frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AppointmentPhone < Common::Resource
      attribute :area_code, Types::String
      attribute :number, Types::String
      attribute :extension, Types::String.optional
    end
  end
end
