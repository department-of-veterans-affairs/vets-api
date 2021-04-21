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
        page = params[:page] || { number: 1, size: 10 }

        validated_params = Mobile::V0::Contracts::GetPaginatedList.new.call(
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
                                 appointments, errors = appointments_proxy.get_appointments(
                                   start_date: validated_params[:start_date], end_date: validated_params[:end_date]
                                 )
                                 Mobile::V0::Appointment.set_cached(@current_user, appointments)
                                 [appointments, errors]
                               end

        page_appointments, page_links = paginate(list: appointments, validated_params: validated_params)

        Mobile::V0::AppointmentSerializer.new(page_appointments, options(errors, page_links))
      end

      def paginate(list:, validated_params:)
        page_number = validated_params[:page_number]
        page_size = validated_params[:page_size]
        pages = list.each_slice(page_size).to_a
        links = links(number_of_pages: pages.size, validated_params: validated_params)
        return [[], links] if page_number > pages.size

        [pages[page_number - 1], links]
      end

      def options(errors, page_links)
        {
          meta: {
            errors: errors.nil? ? nil : errors
          },
          links: page_links
        }
      end

      def links(number_of_pages:, validated_params:)
        page_number = validated_params[:page_number]
        page_size = validated_params[:page_size]

        query_string = "?startDate=#{validated_params[:start_date]}&endDate=#{validated_params[:end_date]}"\
          "&useCache=#{validated_params[:use_cache]}"
        url = request.base_url + request.path + query_string

        if page_number > 1
          prev_link = "#{url}&page[number]=#{[page_number - 1,
                                              number_of_pages].min}&page[size]=#{page_size}"
        end

        if page_number < number_of_pages
          next_link = "#{url}&page[number]=#{[page_number + 1,
                                              number_of_pages].min}&page[size]=#{page_size}"
        end

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
