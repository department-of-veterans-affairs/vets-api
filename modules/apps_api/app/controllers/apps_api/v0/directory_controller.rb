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
        apps = if redis.get('okta_directory_apps')
                          JSON.parse redis.get('okta_directory_apps')
                        else
                          directory_service.get_apps
                        end
        render json: {
          data: apps
        }
      end
    end
  end
end
