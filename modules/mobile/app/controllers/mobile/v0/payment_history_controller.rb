# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'adapters/payment_history_adapter'

module Mobile
  module V0
    class PaymentHistoryController < ApplicationController
      def index
        validated_params = validate_params(params)

        payments = adapter.payments
        available_years = available_years(payments)
        payments = filter(payments, available_years, validated_params) unless payments.empty?
        list, meta = paginate(payments, validated_params)
        meta[:meta][:available_years] = available_years

        render json: Mobile::V0::PaymentHistorySerializer.new(list, meta)
      end

      private

      def validate_params(params)
        Mobile::V0::Contracts::PaymentHistory.new.call(
          start_date: params[:startDate],
          end_date: params[:endDate],
          page_number: params.dig(:page, :number),
          page_size: params.dig(:page, :size),
          reverse_sort: false
        )
      end

      def adapter
        Mobile::V0::Adapters::PaymentHistoryAdapter.new(bgs_service_response)
      end

      def bgs_service_response
        person = BGS::People::Request.new.find_person_by_participant_id(user: current_user)
        if person.response.blank?
          Rails.logger.info('Mobile Payment History Person not found for user icn: ',
                            current_user.icn)
        end
        payment_history = BGS::PaymentService.new(current_user).payment_history(person)
        raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error' if payment_history.nil?

        payment_history
      end

      def available_years(payments)
        payments.map { |p| p.date&.year }.compact.uniq.sort { |a, b| b <=> a }
      end

      def filter(payments, available_years, validated_params)
        start_date = validated_params[:start_date]
        end_date = validated_params[:end_date]

        unless start_date && end_date
          most_recent_year = available_years.first

          unless most_recent_year.is_a? Numeric
            Rails.logger.error('Mobile Payment Error Non Numeric Year', { year_in_error: most_recent_year,
                                                                          available_years: available_years })
          end

          start_date = DateTime.new(most_recent_year).beginning_of_year.utc
          end_date = DateTime.new(most_recent_year).end_of_year.utc
        end

        payments.filter { |payment| payment[:date].between?(start_date, end_date) }
      end

      def paginate(payments, validated_params)
        url = request.base_url + request.path
        Mobile::PaginationHelper.paginate(list: payments, validated_params: validated_params, url: url)
      end
    end
  end
end
