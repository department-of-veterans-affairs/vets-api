# frozen_string_literal: true

# dependencies
require_dependency 'apps_api/application_controller'
require 'okta/directory_service.rb'
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

      def scopes
        directory_service = Okta::DirectoryService.new
        parsed_scopes = directory_service.scopes(params[:category])
        render json: {
          data: parsed_scopes
        }
      end
    end
  end
end
