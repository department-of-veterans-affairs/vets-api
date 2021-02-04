# frozen_string_literal: true

# dependencies
require_dependency 'apps_api/application_controller'
require 'okta/directory_service.rb'
module AppsApi
  module V0
    class DirectoryController < ApplicationController
      skip_before_action(:authenticate)
      before_action :set_directory_application, only: %i[show update destroy]
      before_action :verify_auth, only: %i[create update destroy]

      def index
        render json: {
          data: DirectoryApplication.order('LOWER(name)')
        }
      end

      def show
        render json: {
          data: @directory_application
        }
      end

      def create
        @directory_application = DirectoryApplication.new(directory_application_params)

        if @directory_application.save
          render json: {
            data: @directory_application
          }, status: :ok
        else
          render json: {
            data: @directory_application.errors
          }, status: :unprocessable_entity
        end
      end

      def update
        if @directory_application.update(directory_application_params)
          render json: {
            data: @directory_application
          }, status: :ok
        else
          render json: {
            data: @directory_application.errors
          }, status: :unprocessable_entity
        end
      end

      def destroy
        @directory_application.destroy
        head :ok
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

      private

      def verify_auth
        # put this secret in settings.local.yml
        head :unauthorized unless request.authorization == Settings.directory.key
      end

      def set_directory_application
        @directory_application = DirectoryApplication.find_by(name: params[:id])
      end

      def directory_application_params
        params.require(:directory_application).permit(
          :name, :logo_url, :app_type, :app_url, :description, :privacy_url,
          :tos_url, { service_categories: [] }, { platforms: [] }
        )
      end
    end
  end
end
