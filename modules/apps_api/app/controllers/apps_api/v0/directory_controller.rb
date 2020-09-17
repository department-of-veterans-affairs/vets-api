# frozen_string_literal: true

# dependencies
require_dependency 'apps_api/application_controller'

module AppsApi
  module V0
    class DirectoryController < ApplicationController
      skip_before_action(:authenticate)

      def index
        redis = Redis.new
        directory_service = Okta::DirectoryService.new
        filtered_apps = if redis.get('okta_directory_apps')
                          JSON.parse redis.get('okta_directory_apps')
                        else
                          directory_service.get_apps
                        end
        auth_server_map = JSON.parse redis.get('okta_auth_server_map')
        filtered_apps = directory_service.parse_scope_permissions(filtered_apps, auth_server_map)
        render json: {
          data: filtered_apps
        }
      end
    end
  end
end
