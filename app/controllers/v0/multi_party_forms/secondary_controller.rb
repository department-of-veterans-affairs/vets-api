# frozen_string_literal: true

module V0
  module MultiPartyForms
    class SecondaryController < ApplicationController
      service_tag 'multi-party-forms'
      before_action :check_feature_enabled

      # GET /v0/multi_party_forms/secondary/:id
      def show
        @submission = MultiPartyFormSubmission.find_by!(
          id: params[:id],
          secondary_user_uuid: current_user.uuid
        )

        render json: { data: show_response_data }
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, params[:id]
      rescue => e
        handle_show_error(e)
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

        StatsD.increment(
          'multi_party_form.secondary_started',
          tags: ["form_type:#{@submission.form_type}"]
        )

        render json: { data: start_response_data }
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, params[:id]
      end

      private

      def check_feature_enabled
        routing_error unless Flipper.enabled?(:form_2680_multi_party_forms_enabled, current_user)
      end

      def validate_token_and_state
        unless @submission.verify_secondary_token(params[:token])
          raise Common::Exceptions::Forbidden,
                detail: 'The access token is invalid or has expired'
        end
        unless @submission.may_secondary_start?
          raise Common::Exceptions::UnprocessableEntity,
                detail: 'Submission cannot be started in its current state'
        end
      end

      def show_response_data
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

      def start_response_data
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

      def handle_show_error(error)
        Rails.logger.error(
          'MultiPartyForms::SecondaryController: Error retrieving submission',
          {
            submission_id: params[:id],
            user_id: current_user&.uuid,
            error: error.message,
            backtrace: error.backtrace&.first(5)
          }
        )

        StatsD.increment('multi_party_form.secondary.show.failure')
        raise
      end
    end
  end
end
