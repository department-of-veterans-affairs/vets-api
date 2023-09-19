# frozen_string_literal: true

require 'rest-client'

module V0
  module Profile
    class ConnectedApplicationsController < ApplicationController
      include IgnoreNotFound

      def index
        render json: apps_from_grants, each_serializer: OktaAppSerializer
      end

      def destroy
        icn = @current_user.icn
        client_id = connected_accounts_params[:id]

        if icn.nil? || client_id.nil?
          render json: { error: 'icn and/or clientId is missing' }
          return
        end

        revocation_url = Settings.connected_apps_api.connected_apps.revoke_url

        payload = { icn:, clientId: client_id }
        url_with_params = "#{revocation_url}?#{URI.encode_www_form(payload)}"
        headers = { apiKey: Settings.connected_apps_api.connected_apps.api_key }

        begin
          response = RestClient::Request.execute(method: :delete, url: url_with_params, headers:)

          if response.code == 204
            head :no_content
          else
            render json: { error: 'Something went wrong cannot revoke grants' }, status: :unprocessable_entity
          end
        end
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
