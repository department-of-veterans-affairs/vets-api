# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestDecisionsController < ApplicationController
      include PowerOfAttorneyRequests

      before_action do
        authorize PowerOfAttorneyRequestDecision
      end

      with_options only: :create do
        before_action do
          id = params[:power_of_attorney_request_id]
          set_poa_request(id)
        end
      end

      # rubocop:disable Metrics/MethodLength
      def create
        type = deserialize_type
        reason = decision_params[:reason]

        ApplicationRecord.transaction do
          resolving = PowerOfAttorneyRequestDecision.create!(type:, creator:)

          ##
          # This form triggers the uniqueness validation, while the
          # `@poa_request.create_resolution!` form triggers a more obscure
          # `RecordNotSaved` error that is less functional for getting
          # validation errors.
          #
          PowerOfAttorneyRequestResolution.create!(
            power_of_attorney_request: @poa_request,
            resolving:,
            reason:
          )
        end

        track_request('Decision made', tags: [Monitoring::Tag::Operation::DECISION,
                                              Monitoring::Tag::Status::SUCCESS, "type:#{type}"])

        if @poa_request.created_at.present? && Time.current >= @poa_request.created_at
          decision_time_ms = (Time.current - @poa_request.created_at) * 1000
          StatsD.measure(Monitoring::Metric::POA_DECISION_TIME, decision_time_ms, tags: [
                           "decision:#{type}", "reason:#{reason}"
                         ])
        else
          Rails.logger.warn("POA request #{@poa_request.id} has an invalid created_at timestamp.")
        end
        render json: {}, status: :ok
      end
      # rubocop:enable Metrics/MethodLength

      private

      def deserialize_type
        case decision_params[:type]
        when 'acceptance'
          PowerOfAttorneyRequestDecision::Types::ACCEPTANCE
        when 'declination'
          PowerOfAttorneyRequestDecision::Types::DECLINATION
        else
          Rails.logger.warn("Invalid decision type: #{decision_params[:type]}")

          # So that validations will get their chance to complain.
          decision_params[:type]
        end
      end

      def decision_params
        params.require(:decision).permit(:type, :reason)
      end

      def creator
        current_user.user_account
      end
    end
  end
end
