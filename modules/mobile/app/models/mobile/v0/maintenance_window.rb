# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class MaintenanceWindow < Common::Resource
      attribute :id, Types::String
      attribute :service, Types::String
      attribute :start_time, Types::DateTime
      attribute :end_time, Types::DateTime
    end
  end
end
