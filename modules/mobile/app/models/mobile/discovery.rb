# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  class Discovery < Common::Resource
    attribute :id, Types::String
    attribute :auth_base_url, Types::String
    attribute :api_root_url, Types::String
    attribute :minimum_version, Types::String
    attribute :maintenance_windows, Types::Array.of(Mobile::MaintenanceWindow)
    attribute :web_views, Types::Hash
  end
end
