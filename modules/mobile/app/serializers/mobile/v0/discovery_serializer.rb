# frozen_string_literal: true

module Mobile
  module V0
    class DiscoverySerializer
      include FastJsonapi::ObjectSerializer

      attributes :auth_base_url,
                 :api_root_url,
                 :minimum_version,
                 :maintenance_windows,
                 :web_views
    end
  end
end
