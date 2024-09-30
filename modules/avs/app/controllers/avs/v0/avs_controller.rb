# frozen_string_literal: true

module Avs
  module V0
    class AvsController < ApplicationController
      service_tag 'after-visit-summary'
      before_action :feature_enabled
      before_action :authenticate
      before_action :validate_search_params, only: %i[index]
      before_action :validate_sid, only: %i[show]

      def index
        if avs_appointment_response.body.empty?
          render json: {}
        elsif !icns_match?(@current_user.icn, avs_appointment_response.body[0]['icn'])
          render_client_error('Not authorized', 'User may not view the AVS for this appointment.', :unauthorized)
        else
          render json: { path: avs_path(avs_appointment_response.body[0]['sid']) }
        end
      end

      def show
        if avs_sid_response[:status] == 404
          render_client_error('Not found', "No AVS found for sid #{params['sid']}", :not_found)
        elsif !icns_match?(@current_user.icn, avs_sid_response.avs.icn)
          render_client_error('Not authorized', 'User may not view this AVS.', :unauthorized)
        else
          render json: Avs::V0::AfterVisitSummarySerializer.new(avs_sid_response.avs)
        end
      end

      private

      def avs_service
        @avs_service ||= Avs::V0::AvsService.new
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:avs_enabled, @current_user)
      end

      def avs_path(sid)
        # TODO: define and use constant for base path.
        "/my-health/medical-records/summaries-and-notes/visit-summary/#{sid}"
      end

      def avs_params
        params.permit(:stationNo, :appointmentIen, :sid)
      end

      def avs_sid_response
        @avs_appointment_response ||= begin
          avs_service.get_avs(avs_params[:sid])
        end
      end

      def avs_appointment_response
        @avs_appointment_response ||= begin
          avs_service.get_avs_by_appointment(avs_params[:stationNo], avs_params[:appointmentIen])
        end
      end

      def validate_search_params
        unless validate_search_param?(avs_params[:stationNo]) && validate_search_param?(avs_params[:appointmentIen])
          render_client_error('Invalid parameters', 'Station number and Appointment IEN must be present and valid.')
        end
      end

      def validate_search_param?(param)
        !param.nil? && /^\d+$/.match(param)
      end

      def validate_sid
        unless /^[[:xdigit:]]{30,40}$/.match(params[:sid])
          render_client_error('Invalid AVS id', 'AVS id does not match accepted format.')
        end
      end

      def normalize_icn(icn)
        icn&.gsub(/V[\d]{6}$/, '')
      end

      def icns_match?(icn_a, icn_b)
        return false unless icn_a && icn_b

        normalize_icn(icn_a) == normalize_icn(icn_b)
      end

      def render_client_error(title, message, status = :bad_request)
        error = { title:, detail: message, status: }
        render json: { errors: [error] }, status:
      end
    end
  end
end
