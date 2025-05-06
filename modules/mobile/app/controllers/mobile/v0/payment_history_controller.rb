# frozen_string_literal: true

require 'adapters/payment_history_adapter'

module Mobile
  module V0
    class PaymentHistoryController < ApplicationController
      before_action { authorize :bgs, :access? }

      def index
        validated_params = validate_params(params)

        unfiltered_payments = adapter.payments
        available_years = available_years(unfiltered_payments)
        payments = unfiltered_payments.empty? ? [] : filter(unfiltered_payments, available_years, validated_params)
        list, meta = paginate(payments, validated_params)
        meta[:meta][:available_years] = available_years
        meta[:meta][:recurring_payment] = recurring_payment(unfiltered_payments)

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
        payment_history = BGS::PaymentService.new(current_user).payment_history(person)
        raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error' if payment_history.nil?

        payment_history
      end

      def available_years(payments)
        payments.map { |p| p.date&.year }.compact.uniq.sort { |a, b| b <=> a }
      end

      def recurring_payment(payments)
        payment = payments&.find { |p| p[:payment_type] == 'Compensation & Pension - Recurring' }
        return {} unless payment

        {
          amount: payment[:amount],
          date: payment[:date]
        }
      end

      def filter(payments, available_years, validated_params)
        start_date = validated_params[:start_date]
        end_date = validated_params[:end_date]

        unless start_date && end_date
          most_recent_year = available_years.first
          start_date = DateTime.new(most_recent_year).beginning_of_year.utc
          end_date = DateTime.new(most_recent_year).end_of_year.utc
        end

        payments.filter { |payment| payment[:date].between?(start_date, end_date) }
      end

      def paginate(payments, validated_params)
        Mobile::PaginationHelper.paginate(list: payments, validated_params:)
      end
    end
  end
end
