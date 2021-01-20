# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Discovery < Common::Resource
      attribute :id, Types::String
      attribute :webviews, Types::Hash
      attribute :endpoints, Types::Hash
      attribute :display_message, Types::String
      attribute :app_access, Types::Bool
      attribute :auth_base_url, Types::String
      attribute :api_root_url, Types::String
    end
  end
end
