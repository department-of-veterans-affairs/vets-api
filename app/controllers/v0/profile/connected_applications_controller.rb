# frozen_string_literal: true

module V0
  module Profile
    class ConnectedApplicationsController < ApplicationController
      include IgnoreNotFound
      service_tag 'profile'

      def index
        render json: apps_from_grants
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
          response = Faraday.delete(url_with_params, nil, headers)

          if response.status == 204
            head :no_content
          else
            render json: { error: 'Something went wrong cannot revoke grants' }, status: :unprocessable_entity
          end
        rescue
          render json: { error: 'Something went wrong cannot revoke grants' }, status: :unprocessable_entity
        end
      end

      private

      def apps_from_grants
        data = []
        icn = @current_user.icn

        grant_url = Settings.connected_apps_api.connected_apps.url

        payload = { icn: }
        url_with_params = "#{grant_url}?#{URI.encode_www_form(payload)}"
        headers = { apiKey: Settings.connected_apps_api.connected_apps.api_key }
        response = Faraday.get(url_with_params, {}, headers)

        if response.status == 200
          parsed_response = JSON.parse(response.body)
          lhapps = parsed_response['apps']
          lhapps.each do |lh_app|
            app = build_apps_from_data(lh_app)
            (data ||= []) << app
          end
          { 'data' => data }
        else
          { data: [] }
        end
      rescue
        { data: [] }
      end

      def build_apps_from_data(lh_app)
        app = {}
        app['id'] = lh_app['clientId']
        app['type'] = 'lighthouse_consumer_app'
        app['attributes'] = {}
        app['attributes']['title'] = lh_app['label']
        app['attributes']['logo'] = lh_app['href']
        app['attributes']['privacyUrl'] = ''
        app['attributes']['grants'] = build_grants(lh_app['grants'])
        app
      end

      def build_grants(grants)
        grants.map do |grant|
          {
            title: grant['scopeTitle'],
            id: '',
            created: grant['connectionDate']
          }
        end
      end

      def connected_accounts_params
        params.permit(:id)
      end
    end
  end
end
