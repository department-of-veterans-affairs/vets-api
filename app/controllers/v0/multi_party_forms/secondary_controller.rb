# frozen_string_literal: true

module V0
  module MultiPartyForms
    class SecondaryController < ApplicationController
      service_tag 'multi-party-forms'
      before_action :check_feature_enabled

      # GET /v0/multi_party_forms/secondary/:id
      def show
        @submission = find_submission_for_current_user

        render json: { data: response_data_show }
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, params[:id]
      rescue Common::Exceptions::BaseError
        raise
      rescue => e
        handle_error(e, 'show')
      end

      # POST /v0/multi_party_forms/secondary/:id/start
      def start
        @submission = MultiPartyFormSubmission.find(params[:id])
        validate_token_and_state

        ActiveRecord::Base.transaction do
          secondary_form = create_secondary_form
          update_submission_with_secondary(secondary_form)
          @submission.secondary_start!
        end

        track_metric('secondary.start.success')
        render json: { data: response_data_start }
      rescue AASM::InvalidTransition => e
        handle_state_transition_error(e, 'start')
      rescue ActiveRecord::RecordInvalid => e
        handle_validation_error(e)
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, params[:id]
      rescue Common::Exceptions::BaseError
        raise
      rescue => e
        handle_error(e, 'start')
      end

      # POST /v0/multi_party_forms/secondary/:id/complete
      def complete
        @submission = find_submission_for_current_user
        validate_submission_state

        ActiveRecord::Base.transaction do
          update_secondary_form_data if secondary_params[:form_data].present?
          @submission.secondary_complete!
        end

        track_metric('secondary.complete.success')
        render json: { data: response_data_complete }
      rescue AASM::InvalidTransition => e
        handle_state_transition_error(e, 'complete')
      rescue ActiveRecord::RecordInvalid => e
        handle_validation_error(e)
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, params[:id]
      rescue Common::Exceptions::BaseError
        raise
      rescue => e
        handle_error(e, 'complete')
      end

      private

      def check_feature_enabled
        routing_error unless Flipper.enabled?(:form_2680_multi_party_forms_enabled, current_user)
      end

      def find_submission_for_current_user
        MultiPartyFormSubmission.find_by!(
          id: params[:id],
          secondary_user_uuid: current_user.uuid
        )
      end

      def validate_token_and_state
        unless @submission.verify_secondary_token(params[:token])
          raise Common::Exceptions::Forbidden,
                detail: 'The access token is invalid or has expired'
        end
      end

      def validate_submission_state
        unless @submission.secondary_in_progress?
          raise Common::Exceptions::UnprocessableEntity,
                detail: 'The submission must be in secondary_in_progress state to be completed'
        end
      end

      def secondary_params
        params.permit(form_data: {})
      end

      def response_data_show
        {
          id: @submission.id,
          type: 'multi_party_form_submission',
          attributes: {
            form_type: @submission.form_type,
            status: @submission.status,
            primary_form_id: @submission.primary_form_id,
            secondary_form_id: @submission.secondary_form_id,
            created_at: @submission.created_at.iso8601,
            veteran_sections: {
              read_only: true,
              data: parse_form_data(@submission.primary_in_progress_form)
            },
            physician_sections: {
              editable: true,
              data: parse_form_data(@submission.secondary_in_progress_form)
            }
          }
        }
      end

      def response_data_start
        {
          id: @submission.id,
          type: 'multi_party_form_submission',
          attributes: {
            form_type: @submission.form_type,
            status: @submission.status,
            primary_form_id: @submission.primary_form_id,
            secondary_form_id: @submission.secondary_form_id,
            created_at: @submission.created_at.iso8601,
            veteran_sections: { read_only: true }
          }
        }
      end

      def response_data_complete
        {
          id: @submission.id,
          type: 'multi_party_form_submission',
          attributes: {
            form_type: @submission.form_type,
            status: @submission.status,
            secondary_completed_at: @submission.secondary_completed_at&.iso8601,
            message: 'Secondary form completed successfully'
          }
        }
      end

      def create_secondary_form
        InProgressForm.create!(
          form_id: @submission.secondary_form_id,
          user_uuid: current_user.uuid,
          user_account: current_user.user_account,
          form_data: {}.to_json,
          metadata: {}.to_json
        )
      end

      def update_submission_with_secondary(secondary_form)
        @submission.update!(
          secondary_user_uuid: current_user.uuid,
          secondary_in_progress_form: secondary_form
        )
      end

      def update_secondary_form_data
        raise 'Secondary form is missing!' unless @submission.secondary_in_progress_form

        @submission.secondary_in_progress_form.update!(
          form_data: secondary_params[:form_data].to_json
        )
      end

      def parse_form_data(in_progress_form)
        return {} if in_progress_form.blank?

        JSON.parse(in_progress_form.form_data)
      rescue JSON::ParserError => e
        Rails.logger.error(
          'MultiPartyForms::SecondaryController: Error parsing form data',
          {
            in_progress_form_id: in_progress_form&.id,
            error: e.message
          }
        )
        {}
      end

      def track_metric(event)
        StatsD.increment(
          "multi_party_form.#{event}",
          tags: ["form_type:#{@submission.form_type}"]
        )
      end

      def handle_state_transition_error(error, action)
        Rails.logger.warn(
          "MultiPartyForms::SecondaryController: Invalid state transition on #{action}",
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            current_status: @submission&.status,
            error: error.message
          }
        )
        render json: {
          errors: [{
            title: 'Invalid state transition',
            detail: "The submission cannot be #{action}ed in its current state",
            status: '422'
          }]
        }, status: :unprocessable_entity
      end

      def handle_validation_error(error)
        Rails.logger.warn(
          'MultiPartyForms::SecondaryController: Validation error',
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            error: error.message
          }
        )
        render json: {
          errors: [{
            title: 'Validation failed',
            detail: 'Unable to process the request due to invalid data',
            status: '422'
          }]
        }, status: :unprocessable_entity
      end

      def handle_error(error, action)
        Rails.logger.error(
          "MultiPartyForms::SecondaryController: Error in #{action} action",
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            error: error.message,
            backtrace: error.backtrace&.first(5)
          }
        )
        track_metric("secondary.#{action}.failure")
        raise
      end
    end
  end
end
