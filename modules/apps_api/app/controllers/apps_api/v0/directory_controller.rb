# frozen_string_literal: true

# dependencies
require_dependency 'apps_api/application_controller'

module AppsApi
  module V0
    class DirectoryController < ApplicationController
      skip_before_action(:authenticate)

      def index
        apps = DirectoryApplication.all
        render json: {
          data: apps
        }
      end
    end
  end
end
