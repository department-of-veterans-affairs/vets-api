# frozen_string_literal: true

module V0
  module Profile
    class ConnectedApplicationsController < ApplicationController
      def index
        render json: apps_from_grants, each_serializer: OktaAppSerializer
      end

      def destroy
        app = OktaRedis::App.with_id(connected_accounts_params[:id])
        app.user = @current_user

        app.delete_grants

        head :no_content
      end

      private

      def apps_from_grants
        apps = {}
        @current_user.okta_grants.all.each do |grant|
          links = grant['_links']
          app_id = links['app']['href'].split('/').last
          unless apps[app_id]
            app = OktaRedis::App.with_id(app_id)
            app.user = @current_user
            app.fetch_grants
            apps[app_id] = app
          end
        end
        apps.values
      end

      def connected_accounts_params
        params.permit(:id)
      end
    end
  end
end
