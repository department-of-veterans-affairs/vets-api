# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'
require 'mobile/v0/exceptions/validation_errors'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      after_action :clear_appointments_cache, only: :cancel

      def index
        use_cache = params[:useCache] || true
        start_date = params[:startDate] || one_year_ago.iso8601
        end_date = params[:endDate] || one_year_from_now.iso8601
        reverse_sort = !(params[:sort] =~ /-startDateUtc/).nil?

        validated_params = Mobile::V0::Contracts::GetPaginatedList.new.call(
          start_date: start_date,
          end_date: end_date,
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          use_cache: use_cache,
          reverse_sort: reverse_sort,
          included: params[:included]
        )

        raise Mobile::V0::Exceptions::ValidationErrors, validated_params if validated_params.failure?

        appointments = fetch_cached_or_service(validated_params)
        page_appointments, page_meta_data = paginate(appointments, validated_params)
        if validated_params[:included]&.include?('pending')
          page_meta_data[:links] = include_pending_in_links(page_meta_data[:links])
        end

        render json: Mobile::V0::AppointmentSerializer.new(page_appointments, page_meta_data)
      end

      def cancel
        decoded_cancel_params = Mobile::V0::Appointment.decode_cancel_id(params[:id])
        contract = Mobile::V0::Contracts::CancelAppointment.new.call(decoded_cancel_params)
        raise Mobile::V0::Exceptions::ValidationErrors, contract if contract.failure?

        appointments_proxy.put_cancel_appointment(decoded_cancel_params)
        head :no_content
      end

      private

      def use_cache?(validated_params)
        # use cache if date range is within +/- 1 year and use_cache is true
        validated_params[:start_date] >= one_year_ago.iso8601 &&
          validated_params[:end_date] <= one_year_from_now.iso8601 && validated_params[:use_cache]
      end

      def clear_appointments_cache
        Mobile::V0::Appointment.clear_cache(@current_user)
      end

      def one_year_ago
        (DateTime.now.utc.beginning_of_day - 1.year)
      end

      def one_year_from_now
        (DateTime.now.utc.beginning_of_day + 1.year)
      end

      def fetch_cached_or_service(validated_params)
        appointments = nil
        appointments = Mobile::V0::Appointment.get_cached(@current_user) if use_cache?(validated_params)

        # if appointments has been retrieved from redis, delete the cached version and return recovered appointments
        # otherwise fetch appointments from the upstream service
        if appointments
          Rails.logger.info('mobile appointments cache fetch', user_uuid: @current_user.uuid)
        else
          appointments = appointments_proxy.get_appointments(
            start_date: [validated_params[:start_date], one_year_ago].min,
            end_date: [validated_params[:end_date], one_year_from_now].max
          )
          Mobile::V0::Appointment.set_cached(@current_user, appointments)
          Rails.logger.info('mobile appointments service fetch', user_uuid: @current_user.uuid)
        end

        appointments.filter! { |appt| appt.is_pending == false } unless validated_params[:included]&.include?('pending')
        appointments.reverse! if validated_params[:reverse_sort]

        appointments
      end

      def paginate(appointments, validated_params)
        appointments = appointments.filter do |appointment|
          appointment.start_date_utc.between?(
            validated_params[:start_date].beginning_of_day, validated_params[:end_date].end_of_day
          )
        end
        url = request.base_url + request.path
        Mobile::PaginationHelper.paginate(list: appointments, validated_params: validated_params, url: url)
      end

      def include_pending_in_links(links)
        links.transform_values do |v|
          v.nil? ? nil : "#{v}&included[]=pending"
        end
      end

      def appointments_proxy
        Mobile::V0::Appointments::Proxy.new(@current_user)
      end
    end
  end
end
