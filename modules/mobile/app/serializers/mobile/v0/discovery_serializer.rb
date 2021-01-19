# frozen_string_literal: true

module Mobile
  module V0
    class DiscoverySerializer
      include FastJsonapi::ObjectSerializer

      attributes :webviews, :endpoints, :display_message, :app_access, :oauth_base_url
    end
  end
end
