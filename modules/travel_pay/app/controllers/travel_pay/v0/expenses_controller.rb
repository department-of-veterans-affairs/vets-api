# frozen_string_literal: true

require 'travel_pay/constants'

module TravelPay
  module V0
    class ExpensesController < ApplicationController
      include FeatureFlagHelper
      include IdValidation

      before_action :validate_claim_id!, only: %i[create show]
      before_action :validate_expense_id!, only: %i[destroy show update]
      before_action :validate_expense_type!
      before_action :check_feature_flag

      def show
        Rails.logger.info(message: 'Travel Pay expense retrieval START')
        Rails.logger.info(message: <<~LOG_MESSAGE.strip)
          Getting expense of type '#{params[:expense_type]}'
          with ID #{params[:expense_id].slice(0, 8)}
          for claim #{params[:claim_id].slice(0, 8)}
        LOG_MESSAGE

        expense = expense_service.get_expense(params[:expense_type], params[:expense_id])

        Rails.logger.info(message: 'Travel Pay expense retrieval END')

        render json: expense, status: :ok
      rescue ArgumentError => e
        raise Common::Exceptions::BadRequest, detail: e.message
      rescue Faraday::Error => e
        TravelPay::ServiceError.raise_mapped_error(e)
      end

      def create
        Rails.logger.info(message: 'Travel Pay expense submission START')
        Rails.logger.info(
          message: "Creating expense of type '#{params[:expense_type]}' for claim #{params[:claim_id].slice(0, 8)}"
        )
        expense = create_and_validate_expense
        created_expense = expense_service.create_expense(expense_params_for_service(expense))

        Rails.logger.info(message: 'Travel Pay expense submission END')

        render json: created_expense, status: :created
      rescue ArgumentError => e
        raise Common::Exceptions::BadRequest, detail: e.message
      rescue Faraday::Error => e
        TravelPay::ServiceError.raise_mapped_error(e)
      end

      def update
        expense_type = params[:expense_type]
        expense_id = params[:expense_id]
        Rails.logger.info(
          message: "Updating expense of type '#{expense_type}' with expense id #{expense_id&.first(8)}"
        )
        expense = create_and_validate_expense
        response_data = expense_service.update_expense(expense_id, expense_type, expense_params_for_service(expense))

        render json: { id: response_data['id'] }, status: :ok
      rescue ArgumentError => e
        raise Common::Exceptions::BadRequest, detail: e.message
      rescue Faraday::ClientError, Faraday::ServerError => e
        TravelPay::ServiceError.raise_mapped_error(e)
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error("Error updating expense: #{e.message}")
        render json: { error: 'Error updating expense' }, status: e.original_status
      end

      def destroy
        expense_type = params[:expense_type]
        expense_id = params[:expense_id]

        Rails.logger.info(
          message: "Deleting expense of type '#{expense_type}' with expense id #{expense_id&.first(8)}"
        )
        response_data = expense_service.delete_expense(expense_id:, expense_type:)

        render json: { id: response_data['id'] }, status: :ok
      rescue ArgumentError => e
        raise Common::Exceptions::BadRequest, detail: e.message
      rescue Faraday::ClientError, Faraday::ServerError => e
        TravelPay::ServiceError.raise_mapped_error(e)
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error("Error deleting expense: #{e.message}")
        render json: { error: 'Error deleting expense' }, status: e.original_status
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
          error_message: 'Travel Pay expense endpoint unavailable per feature toggle'
        )
      end

      def create_and_validate_expense
        expense = build_expense_from_params

        return expense if expense.valid?

        Rails.logger.error(message: "Expense validation failed: #{expense.errors.full_messages}")
        raise Common::Exceptions::UnprocessableEntity, detail: expense.errors.full_messages.join(', ')
      end

      def validate_claim_id!
        validate_uuid_exists!(params[:claim_id], 'Claim')
      end

      def validate_expense_id!
        validate_uuid_exists!(params[:expense_id], 'Expense')
      end

      def validate_expense_type!
        raise Common::Exceptions::BadRequest, detail: 'Expense type is required' if params[:expense_type].blank?

        unless valid_expense_types.include?(params[:expense_type])
          raise Common::Exceptions::BadRequest,
                detail: "Invalid expense type. Must be one of: #{valid_expense_types.join(', ')}"
        end
      end

      def validate_expense_id
        raise Common::Exceptions::BadRequest, detail: 'Expense ID is required' if params[:expense_id].blank?

        uuid_all_version_format = /\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}\z/i

        unless uuid_all_version_format.match?(params[:expense_id])
          raise Common::Exceptions::BadRequest.new(
            detail: 'Expense ID is invalid'
          )
        end
      end

      def valid_expense_types
        TravelPay::Constants::BASE_EXPENSE_PATHS.keys.map(&:to_s)
      end

      def build_expense_from_params
        expense_class = expense_class_for_type(params[:expense_type])
        expense_params = permitted_params.to_h

        # Manually extract the 'receipt' object from the raw params, bypassing Strong Params filtering
        expense_params[:receipt] = params[:receipt] if params[:receipt].present?

        # Only add claim_id if it exists in params
        expense_params[:claim_id] = params[:claim_id] if params[:claim_id].present?

        expense_class.new(expense_params)
      end

      def expense_class_for_type(expense_type)
        return TravelPay::BaseExpense if expense_type.nil?

        case expense_type.to_sym
        when :airtravel
          TravelPay::FlightExpense
        when :common_carrier
          TravelPay::CommonCarrierExpense
        when :lodging
          TravelPay::LodgingExpense
        when :meal
          TravelPay::MealExpense
        when :mileage
          TravelPay::MileageExpense
        when :parking
          TravelPay::ParkingExpense
        when :toll
          TravelPay::TollExpense
        else
          # :other or any unknown type defaults to BaseExpense
          TravelPay::BaseExpense
        end
      end

      def permitted_params
        expense_class = expense_class_for_type(params[:expense_type])
        params.permit(*expense_class.permitted_params)
      end

      def expense_params_for_service(expense)
        expense.to_service_params
      end
    end
  end
end
