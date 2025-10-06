# frozen_string_literal: true

module TravelPay
  module V1
    class ComplexClaimsFormProgressController < TravelPay::ApplicationController
      before_action :before_logger, only: %i[show update]
      after_action :after_logger, only: %i[show update]

      def show
        session = TravelPay::ComplexClaimsFormSession.find_or_create_for_user(current_user.icn)
        render json: session.to_progress_json
      rescue => e
        log_exception_to_sentry(e)
        render json: { error: { code: 'internal_error', message: 'Unable to retrieve complex claims form progress' } },
               status: :internal_server_error
      end

      def update
        session = TravelPay::ComplexClaimsFormSession.find_or_create_for_user(current_user.icn)

        session.update_form_step(
          progress_params[:expense_type],
          progress_params[:step_id],
          started: progress_params[:started],
          complete: progress_params[:complete]
        )

        render json: session.to_progress_json
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: { code: 'validation_error', message: e.message } },
               status: :unprocessable_entity
      rescue => e
        log_exception_to_sentry(e)
        render json: { error: { code: 'internal_error', message: 'Unable to update complex claims form progress' } },
               status: :internal_server_error
      end

      def bulk_update
        session = TravelPay::ComplexClaimsFormSession.find_or_create_for_user(current_user.icn)

        bulk_params[:updates].each do |update|
          session.update_form_step(
            update[:expense_type],
            update[:step_id],
            started: update[:started],
            complete: update[:complete]
          )
        end

        render json: session.to_progress_json
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: { code: 'validation_error', message: e.message } },
               status: :unprocessable_entity
      rescue => e
        log_exception_to_sentry(e)
        render json: { error: { code: 'internal_error', message: 'Unable to update complex claims form progress' } },
               status: :internal_server_error
      end

      private

      def progress_params
        params.require(:progress).permit(:expense_type, :step_id, :started, :complete)
      end

      def bulk_params
        params.require(:bulk_progress).permit(updates: %i[expense_type step_id started complete])
      end
    end
  end
end
