# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'
require 'mobile/v0/exceptions/validation_errors'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        use_cache = params[:useCache] || true
        start_date = params[:startDate] || (DateTime.now.utc.beginning_of_day - 1.year).iso8601
        end_date = params[:endDate] || (DateTime.now.utc.beginning_of_day + 1.year).iso8601
        page = params[:page] || { 'number' => 1, 'size' => 10 }

        validated_params = Mobile::V0::Contracts::GetAppointments.new.call(
          start_date: start_date,
          end_date: end_date,
          page_number: page[:number],
          page_size: page[:size],
          use_cache: use_cache
        )

        raise Mobile::V0::Exceptions::ValidationErrors, validated_params if validated_params.failure?

        render json: fetch_cached_or_service(validated_params)
      end

      def cancel
        decoded_cancel_params = Mobile::V0::Appointment.decode_cancel_id(params[:id])
        contract = Mobile::V0::Contracts::CancelAppointment.new.call(decoded_cancel_params)
        raise Mobile::V0::Exceptions::ValidationErrors, contract if contract.failure?

        appointments_proxy.put_cancel_appointment(decoded_cancel_params)
        head :no_content
      end

      private

      def fetch_cached_or_service(validated_params)
        appointments = nil
        appointments = Mobile::V0::Appointment.get_cached(@current_user) if validated_params[:use_cache]

        # if appointments has been retrieved from redis, delete the cached version and return recovered appointments
        # otherwise fetch appointments from the upstream service
        appointments, errors = if appointments
                                 Rails.logger.info('mobile appointments cache fetch', user_uuid: @current_user.uuid)
                                 [appointments, nil]
                               else
                                 Rails.logger.info('mobile appointments service fetch', user_uuid: @current_user.uuid)
                                 appointments, errors = appointments_proxy.get_appointments(validated_params.to_h.except(:page_number, :page_size))
                                 Mobile::V0::Appointment.set_cached(@current_user, appointments)
                                 [appointments, errors]
                               end

        page_appointments, page_links = paginate(list: appointments, page_number: 1, page_size: 10,
                                                 validated_params: validated_params)

        options = {
          meta: {
            errors: errors.nil? ? nil : errors
          },
          links: page_links
        }

        Mobile::V0::AppointmentSerializer.new(page_appointments, options)
      end

      def paginate(list:, validated_params:, page_number: 1, page_size: 10)
        pages = list.each_slice(page_size).to_a
        return nil if page_number > pages.size

        [pages[page_number - 1], links(page_number, page_size, pages.size, validated_params)]
      end

      def links(page_number, page_size, number_of_pages, validated_params)
        endpoint_url = request.base_url + request.path_info
        query_string = "?startDate=#{validated_params[:start_date]}&endDate=#{validated_params[:end_date]}"\
          "&useCache=#{validated_params[:use_cache]}"
        url = endpoint_url + query_string

        prev_link = nil
        next_link = nil

        prev_link = "#{url}&page[number]=#{page_number - 1}&page[size]=#{page_size}" if page_number > 1

        next_link = "#{url}&page[number]=#{page_number + 1}&page[size]=#{page_size}" if page_number < number_of_pages
        
        {
          self: "#{url}&page[number]=#{page_number}&page[size]=#{page_size}",
          first: "#{url}&page[number]=1&page[size]=#{page_size}",
          prev: prev_link,
          next: next_link,
          last: "#{url}&page[number]=#{number_of_pages}&page[size]=#{page_size}"
        }
      end

      def appointments_proxy
        Mobile::V0::Appointments::Proxy.new(@current_user)
      end
    end
  end
end
