# frozen_string_literal: true

module TravelPay
  module V0
    class ExpensesController < ApplicationController
      include FeatureFlagHelper

      before_action :validate_claim_id
      before_action :validate_expense_type
      before_action :check_feature_flag, only: [:create]

      def create
        Rails.logger.info(message: 'Travel Pay expense submission START')
        Rails.logger.info(
          message: "Creating expense of type '#{params[:expense_type]}' for claim #{params[:claim_id].slice(0, 8)}"
        )
        begin
          expense = create_and_validate_expense
          created_expense = expense_service.create_expense(expense_params_for_service(expense))

          Rails.logger.info(message: 'Travel Pay expense submission END')
        rescue ArgumentError => e
          raise Common::Exceptions::BadRequest, detail: e.message
        rescue Faraday::ClientError, Faraday::ServerError => e
          TravelPay::ServiceError.raise_mapped_error(e)
        end

        render json: created_expense, status: :created
      end

      private

      def auth_manager
        @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
      end

      def expense_service
        @expense_service ||= TravelPay::ExpensesService.new(auth_manager)
      end

      def check_feature_flag
        verify_feature_flag!(
          :travel_pay_enable_complex_claims,
          current_user,
          error_message: 'Travel Pay expense submission unavailable per feature toggle'
        )
      end

      def create_and_validate_expense
        expense = build_expense_from_params

        return expense if expense.valid?

        Rails.logger.error(message: "Expense validation failed: #{expense.errors.full_messages}")
        raise Common::Exceptions::UnprocessableEntity, detail: expense.errors.full_messages.join(', ')
      end

      def validate_claim_id
        raise Common::Exceptions::BadRequest, detail: 'Claim ID is required' if params[:claim_id].blank?
      end

      def validate_expense_type
        raise Common::Exceptions::BadRequest, detail: 'Expense type is required' if params[:expense_type].blank?

        unless valid_expense_types.include?(params[:expense_type])
          raise Common::Exceptions::BadRequest,
                detail: "Invalid expense type. Must be one of: #{valid_expense_types.join(', ')}"
        end
      end

      def valid_expense_types
        %w[mileage lodging meal other]
      end

      def build_expense_from_params
        expense_class = expense_class_for_type(params[:expense_type])
        expense_params = permitted_params.merge(claim_id: params[:claim_id])

        expense_class.new(expense_params)
      end

      def expense_class_for_type(_expense_type)
        # TODO: Implement specific expense models (MileageExpense, LodgingExpense, MealExpense)
        # For now, all expense types use BaseExpense
        TravelPay::BaseExpense
      end

      def permitted_params
        params.require(:expense).permit(
          :purchase_date,
          :description,
          :cost_requested,
          :receipt
        )
      end

      def expense_params_for_service(expense)
        {
          'claim_id' => expense.claim_id,
          'purchase_date' => format_purchase_date(expense.purchase_date),
          'description' => expense.description,
          'cost_requested' => expense.cost_requested,
          'expense_type' => expense.expense_type
        }
      end

      # Ensures purchase_date is formatted as ISO8601, regardless of input type
      def format_purchase_date(purchase_date)
        return nil if purchase_date.nil?

        if purchase_date.is_a?(Date) || purchase_date.is_a?(Time) || purchase_date.is_a?(DateTime)
          purchase_date.iso8601
        elsif purchase_date.is_a?(String)
          begin
            Date.iso8601(purchase_date).iso8601
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
