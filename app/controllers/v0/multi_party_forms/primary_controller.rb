# frozen_string_literal: true

module V0
  module MultiPartyForms
    class PrimaryController < ApplicationController
      service_tag 'multi-party-forms'
      before_action :check_feature_enabled

      # GET /v0/multi_party_forms/primary/:id
      # Retrieves submission details for the current user
      def show
        # TODO: Replace with actual model query once available
        # @submission = find_submission_for_current_user
        # render json: MultiPartyFormSerializer.new(@submission)

        # Stubbed response for now
        render json: {
          data: {
            id: params[:id],
            type: 'multi_party_form_submission',
            attributes: {
              form_type: '21-2680',
              status: 'primary_in_progress',
              primary_form_id: '21-2680-PRIMARY',
              secondary_form_id: '21-2680-SECONDARY',
              created_at: Time.current.iso8601
            }
          }
        }
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, params[:id]
      rescue => e
        handle_show_error(e)
      end

      # POST /v0/multi_party_forms/primary
      # Creates a new multi-party form submission and the Primary Party's InProgressForm
      def create
        form_params = params[:multi_party_form]
        form_type = form_params[:form_type]

        # TODO: Replace with actual MultiPartyFormSubmission.new once model is available
        # Expected attributes:
        # - form_type: form_type
        # - primary_user_uuid: current_user.uuid
        # - secondary_email: 'placeholder@pending.com' (updated when Primary Party completes)

        # TODO: Create the coordination record and Primary Party's InProgressForm in a transaction
        # ActiveRecord::Base.transaction do
        #   @submission = MultiPartyFormSubmission.new(
        #     form_type: form_type,
        #     primary_user_uuid: current_user.uuid,
        #     secondary_email: 'placeholder@pending.com'
        #   )
        #
        #   primary_form = InProgressForm.new(
        #     form_id: @submission.primary_form_id,  # e.g., "21-2680-PRIMARY"
        #     user_uuid: current_user.uuid,
        #     form_data: {}.to_json,
        #     metadata: {}.to_json
        #   )
        #
        #   primary_form.save!
        #   @submission.primary_in_progress_form = primary_form
        #   @submission.save!
        # end

        StatsD.increment('multi_party_form.created', tags: ["form_type:#{form_type}"])

        # TODO: Replace with actual serializer once available
        # render json: MultiPartyFormSerializer.new(@submission), status: :created

        # Stubbed response for now
        render json: {
          data: {
            id: SecureRandom.uuid,
            type: 'multi_party_form_submission',
            attributes: {
              form_type:,
              status: 'primary_in_progress',
              primary_form_id: "#{form_type}-PRIMARY",
              secondary_form_id: "#{form_type}-SECONDARY",
              created_at: Time.current.iso8601
            }
          }
        }, status: :created
      rescue => e
        handle_create_error(e)
      end

      # POST /v0/multi_party_forms/primary/:id/complete
      # Called when the Primary Party finishes their sections, signs, and provides the Secondary Party's email.
      # Triggers state transition and enqueues a notification to the Secondary Party.
      def complete
        @submission = find_submission_for_current_user
        complete_primary_submission
        track_completion_metrics
        render_submission_response
      rescue AASM::InvalidTransition => e
        handle_state_transition_error(e)
      rescue ActiveRecord::RecordInvalid => e
        handle_validation_error(e)
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, params[:id]
      rescue => e
        handle_complete_error(e)
      end

      private

      def check_feature_enabled
        routing_error unless Flipper.enabled?(:form_2680_multi_party_forms_enabled, current_user)
      end

      def find_submission_for_current_user
        MultiPartyFormSubmission.find_by!(
          id: params[:id],
          primary_user_uuid: current_user.uuid
        )
      end

      def complete_primary_submission
        ActiveRecord::Base.transaction do
          @submission.secondary_email = complete_params[:secondary_email]
          @submission.primary_complete!
        end
      end

      def complete_params
        params.require(:multi_party_form).permit(:secondary_email)
      end

      def track_completion_metrics
        StatsD.increment('multi_party_form.primary_completed', tags: ["form_type:#{@submission.form_type}"])
      end

      def render_submission_response
        render json: {
          data: {
            id: @submission.id,
            type: 'multi_party_form_submission',
            attributes: {
              form_type: @submission.form_type,
              status: @submission.status,
              primary_form_id: @submission.primary_form_id,
              secondary_form_id: @submission.secondary_form_id,
              secondary_email: @submission.secondary_email,
              primary_completed_at: @submission.primary_completed_at&.iso8601,
              created_at: @submission.created_at.iso8601
            }
          }
        }
      end

      def handle_state_transition_error(error)
        Rails.logger.warn(
          'MultiPartyForms::PrimaryController: Invalid state transition on complete',
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            error: error.message
          }
        )
        render json: {
          errors: [{
            title: 'Invalid state transition',
            detail: 'The submission cannot be completed in its current state',
            status: '422'
          }]
        }, status: :unprocessable_entity
      end

      def handle_validation_error(error)
        Rails.logger.warn(
          'MultiPartyForms::PrimaryController: Validation error on complete',
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            error: error.message
          }
        )
        render json: {
          errors: [{
            title: 'Validation failed',
            detail: error.message,
            status: '422'
          }]
        }, status: :unprocessable_entity
      end

      def handle_create_error(error)
        form_type = params.dig(:multi_party_form, :form_type)

        Rails.logger.error(
          'MultiPartyForms::PrimaryController: Error creating submission',
          {
            form_type:,
            user_id: current_user&.uuid,
            error: error.message,
            backtrace: error.backtrace&.first(5)
          }
        )

        StatsD.increment('multi_party_form.create.failure', tags: ["form_type:#{form_type}"])
        raise
      end

      def handle_complete_error(error)
        Rails.logger.error(
          'MultiPartyForms::PrimaryController: Error completing submission',
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            error: error.message,
            backtrace: error.backtrace&.first(5)
          }
        )
        StatsD.increment('multi_party_form.complete.failure')
        raise
      end

      def handle_show_error(error)
        Rails.logger.error(
          'MultiPartyForms::PrimaryController: Error retrieving submission',
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            error: error.message,
            backtrace: error.backtrace&.first(5)
          }
        )

        StatsD.increment('multi_party_form.show.failure')
        raise
      end
    end
  end
end
