# frozen_string_literal: true

module V0
  module MultiPartyForms
    class SecondaryController < ApplicationController
      service_tag 'multi-party-forms'
      before_action :check_feature_enabled

      # POST /v0/multi_party_forms/secondary/:id/start
      def start
        # TODO: Uncomment when MultiPartyFormSubmission model is merged
        # @submission = MultiPartyFormSubmission.find(params[:id])
        # return render_forbidden unless @submission.verify_secondary_token(params[:token])
        # return render_invalid_state unless @submission.may_secondary_start?

        # ActiveRecord::Base.transaction do
        #   secondary_form = create_secondary_form
        #   update_submission_with_secondary(secondary_form)
        #   @submission.secondary_start!
        # end

        # StatsD.increment(
        #   'multi_party_form.secondary_started',
        #   tags: ["form_type:#{@submission.form_type}"]
        # )

        # Stub response for now
        render json: {
          data: {
            id: params[:id],
            type: 'multi_party_form_submission',
            attributes: {
              form_type: '21-2680',
              status: 'secondary_in_progress',
              primary_form_id: '21-2680',
              secondary_form_id: '21-2680',
              created_at: Time.current.iso8601,
              veteran_sections: { read_only: true }
            }
          }
        }
      # rescue ActiveRecord::RecordNotFound
      #   render_not_found
      rescue => e
        handle_error(e)
      end

      private

      def check_feature_enabled
        routing_error unless Flipper.enabled?(:form_2680_multi_party_forms_enabled, current_user)
      end

      def render_forbidden
        render json: {
          errors: [
            { title: 'Forbidden', detail: 'The access token is invalid or has expired' }
          ]
        }, status: :forbidden
        true
      end

      def render_invalid_state
        render json: {
          errors: [
            { title: 'Invalid submission state', detail: 'Submission cannot be started in its current state' }
          ]
        }, status: :unprocessable_entity
        true
      end

      def create_secondary_form
        # TODO: Uncomment when MultiPartyFormSubmission model is merged
        # InProgressForm.create!(
        #   form_id: @submission.secondary_form_id,
        #   user_uuid: current_user.uuid,
        #   user_account: current_user.user_account,
        #   form_data: {}.to_json,
        #   metadata: {}.to_json
        # )
      end

      def update_submission_with_secondary(secondary_form)
        # TODO: Uncomment when MultiPartyFormSubmission model is merged
        # @submission.update!(
        #   secondary_user_uuid: current_user.uuid,
        #   secondary_in_progress_form: secondary_form
        # )
      end

      def render_not_found
        render json: {
          errors: [
            { title: 'Not found', detail: 'Submission not found' }
          ]
        }, status: :not_found
      end

      def handle_error(error)
        Rails.logger.error(
          'MultiPartyForms::SecondaryController: Error starting secondary flow',
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            error: error.message,
            backtrace: error.backtrace&.first(5)
          }
        )

        StatsD.increment('multi_party_form.secondary_started.failure')
        raise
      end
    end
  end
end
