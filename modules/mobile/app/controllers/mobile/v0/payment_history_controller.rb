# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'adapters/payment_history_adapter'
require 'mobile/v0/exceptions/validation_errors'

module Mobile
  module V0
    class PaymentHistoryController < ApplicationController
      def index
        validated_params = validate_params(params)
        raise Mobile::V0::Exceptions::ValidationErrors, validated_params if validated_params.failure?

        payments = adapter.payments
        list, meta = paginate(payments, validated_params)

        render json: Mobile::V0::PaymentHistorySerializer.new(list, meta)
      end

      private

      def validate_params(params)
        start_date = params[:startDate] || (DateTime.now.utc.beginning_of_day - 1.year).iso8601
        end_date = params[:endDate] || DateTime.now.utc.beginning_of_day.iso8601

        Mobile::V0::Contracts::GetPaginatedList.new.call(
          start_date: start_date,
          end_date: end_date,
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          use_cache: false,
          reverse_sort: false
        )
      end

      def adapter
        Mobile::V0::Adapters::PaymentHistoryAdapter.new(bgs_service_response)
      end

      def bgs_service_response
        person = BGS::PeopleService.new(current_user).find_person_by_participant_id
        BGS::PaymentService.new(current_user).payment_history(person)
      end

      def paginate(payments, validated_params)
        url = request.base_url + request.path
        Mobile::PaginationHelper.paginate(list: payments, validated_params: validated_params, url: url)
      end
    end
  end
end
