# frozen_string_literal: true

module V0
  module Profile
    class ConnectedApplicationsController < ApplicationController
      def index
        render json: grants_by_app.values, serializers: ConnectedApplicationsSerializer
      end

      def destroy
        app = grants_by_app(false)[grants_params[:id]]
        app[:grants].each do |grant|
          unless okta_service.delete_grant(@current_user.uid, grant[:id]).success?
            log_message_to_sentry("Error deleting grant #{grants_params[:id]}", :error,
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

      def grants_by_app(with_logos = true)
        grants_response = okta_service.grants(@current_user.uuid)

        if grants_response.success?
          grants = {}
          grants_response.body.each do |grant|
            links = grant['_links']
            app_href = links['app']['href']
            app_id = app_href.split('/').last

            unless grants[app_id]
              grants[app_id] = {
                id: app_id,
                href: app_href,
                title: links['app']['title'],
                created: grant['created'],
                logo: get_logo(app_id),
                grants: []
              }
              grants[app_id][:logo] = get_logo(app_id) if with_logos
            end

            grants[app_id][:grants] << { id: grant['id'], title: links['scope']['title'] }
          end

          grants
        else
          log_message_to_sentry('Error retrieving grants for user', :error,
                                body: profile_response.body)
          raise 'Unable to retrieve grants for user'
        end
      end

      def connected_accounts_params
        params.require(:id)
      end
    end
  end
end
