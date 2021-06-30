# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  class MaintenanceWindow < Common::Resource
    attribute :service, Types::String
    attribute :start_time, Types::DateTime
    attribute :end_time, Types::DateTime
    attribute :description, Types::String
  end
end
