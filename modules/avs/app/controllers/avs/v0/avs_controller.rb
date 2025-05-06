# frozen_string_literal: true

module Avs
  module V0
    class AvsController < ApplicationController
      service_tag 'after-visit-summary'
      before_action :feature_enabled
      before_action { :authenticate }

      def index
        station_no = params[:stationNo]
        appointment_ien = params[:appointmentIen]
        unless validate_search_param?(station_no) && validate_search_param?(appointment_ien)
          render_client_error('Invalid parameters', 'Station number and Appointment IEN must be present and valid.')
          return
        end

        response = avs_service.get_avs_by_appointment(station_no, appointment_ien)

        if response.body.empty?
          data = {}
        else
          if response.body[0]['icn'].nil? || !icns_match?(@current_user.icn, response.body[0]['icn'])
            render_client_error('Not authorized', 'User may not view the AVS for this appointment.', :unauthorized)
            return
          end

          data = { path: get_avs_path(response.body[0]['sid']) }
        end

        render json: data
      end

      def show
        sid = params['sid']
        unless validate_sid?(sid)
          render_client_error('Invalid AVS id', 'AVS id does not match accepted format.')
          return
        end

        avs_response = avs_service.get_avs(sid)

        if avs_response[:status] == 404
          render_client_error('Not found', "No AVS found for sid #{sid}", :not_found)
          return
        end

        data = avs_response.avs
        if data.icn.nil? || !icns_match?(@current_user.icn, data.icn)
          render_client_error('Not authorized', 'User may not view this AVS.', :unauthorized)
          return
        end

        render json: serializer(data)
      end

      def avs_service
        @avs_service ||= Avs::V0::AvsService.new
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:avs_enabled, @current_user)
      end

      def get_avs_path(sid)
        # TODO: define and use constant for base path.
        "/my-health/medical-records/summaries-and-notes/visit-summary/#{sid}"
      end

      def render_client_error(title, message, status = :bad_request)
        render json: {
          errors: [
            {
              title:,
              detail: message,
              status:
            }
          ]
        }, status:
      end

      def serializer(avs)
        Avs::V0::AfterVisitSummarySerializer.new(avs)
      end

      def validate_search_param?(param)
        !param.nil? && /^\d+$/.match(param)
      end

      def validate_sid?(sid)
        /^[[:xdigit:]]{30,40}$/.match(sid)
      end

      def normalize_icn(icn)
        icn&.gsub(/V[\d]{6}$/, '')
      end

      def icns_match?(icn_a, icn_b)
        normalize_icn(icn_a) == normalize_icn(icn_b)
      end
    end
  end
end
