# frozen_string_literal: true

# dependencies
require_dependency 'apps_api/application_controller'
require 'okta/directory_service.rb'
module AppsApi
  module V0
    class DirectoryController < ApplicationController
      skip_before_action(:authenticate)

      def index
        render json: {
          data: DirectoryApplication.all
        }
      end

      def scopes
        directory_service = Okta::DirectoryService.new
        parsed_scopes = directory_service.scopes(params[:category])
        if parsed_scopes.any? do
          render json: {
            data: parsed_scopes
          }
           rescue
             head :no_content
        end
        end
      end
    end
  end
end
