# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class MilitaryServiceController < ApplicationController
        include MyHealth::AALClientConcerns
        service_tag 'mhv-medical-records'

        before_action :authorize

        class MissingEdipiError < StandardError; end

        ##
        # Get a user's military service record
        #
        # @return [String] military service record in text format
        #
        def index
          raise MissingEdipiError, 'No EDIPI found for the current user' if @current_user.edipi.blank?

          # We only log an AAL entry for this if it was NOT retrieved as part of the Blue Button report.
          is_blue_button = ActiveModel::Type::Boolean.new.cast(params[:bb])

          resource = if is_blue_button
                       client.get_military_service(@current_user.edipi)
                     else
                       handle_aal('DOD military service information records', 'Download', once_per_session: true) do
                         client.get_military_service(@current_user.edipi)
                       end
                     end
          render json: resource.to_json
        rescue MissingEdipiError => e
          render json: { error: e }, status: :bad_request
        end

        protected

        def client
          @phrmgr_client ||= PHRMgr::Client.new(current_user.icn)
        end

        def authorize
          raise_access_denied if current_user.icn.blank?
        end

        def raise_access_denied
          raise Common::Exceptions::Forbidden, detail: 'You do not have access to military service information'
        end

        def product
          :mr
        end
      end
    end
  end
end
