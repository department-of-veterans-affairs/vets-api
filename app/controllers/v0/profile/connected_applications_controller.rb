# frozen_string_literal: true

module V0
  module Profile
    class ConnectedApplicationsController < ApplicationController
      def index
        render json: { data: grants_by_app.values }
      end

      def destroy
        app = grants_by_app(false)[connected_accounts_params[:id]]
        app[:attributes][:grants].each do |grant|
          delete_response = okta_service.delete_grant(@current_user.uuid, grant[:id])
          unless delete_response.success?
            log_message_to_sentry("Error deleting grant #{connected_accounts_params[:id]}", :error,
                                  body: delete_response.body)
            raise 'Unable to delete grant'
          end
        end

        head :no_content
      end

      private

      def okta_service
        @okta_service ||= Okta::Service.new
      end

      def get_logo(app_id)
        app_response = okta_service.app(app_id)
        if app_response.success?
          app_response.body['_links']['logo'].last['href']
        else
          log_message_to_sentry('Error fetching app', :error,
                                body: app_response.body)
          raise 'Unable to fetch app'
        end
      end

      def apps_from_grants(grants, with_logos = true)
        apps = {}
        grants.body.each do |grant|
          links = grant['_links']
          app_href = links['app']['href']
          app_id = app_href.split('/').last

          unless apps[app_id]
            apps[app_id] = {
              id: app_id,
              type: 'connectedApplication',
              attributes: {
                title: links['app']['title'],
                created: grant['created'],
                grants: []
              }
            }
            apps[app_id][:attributes][:logo] = get_logo(app_id) if with_logos
          end

          apps[app_id][:attributes][:grants] << { id: grant['id'], title: links['scope']['title'] }
        end
        apps
      end

      def grants_by_app(with_logos = true)
        grants_response = okta_service.grants(@current_user.uuid)

        if grants_response.success?
          apps_from_grants(grants_response, with_logos)
        else
          log_message_to_sentry('Error retrieving grants for user', :error,
                                body: grants_response.body)
          raise 'Unable to retrieve grants for user'
        end
      end

      def connected_accounts_params
        params.permit(:id)
      end
    end
  end
end
