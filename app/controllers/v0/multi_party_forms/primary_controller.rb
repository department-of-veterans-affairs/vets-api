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

      private

      def check_feature_enabled
        routing_error unless Flipper.enabled?(:form_2680_multi_party_forms_enabled, current_user)
      end

      def find_submission_for_current_user
        # TODO: Uncomment once MultiPartyFormSubmission model is available
        # MultiPartyFormSubmission.find_by!(
        #   id: params[:id],
        #   primary_user_uuid: current_user.uuid
        # )

        # Stubbed for now - will raise RecordNotFound if implemented
        raise ActiveRecord::RecordNotFound if params[:id] == 'not-found'
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
