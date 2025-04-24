# frozen_string_literal: true

module V0
  class EventBusGatewayController < ApplicationController
    # TEMPORARY FOR INITIAL DEVELOPMENT
    skip_before_action :authenticate, only: :send_email
    EMAIL_PARAMS = %i[
      participant_id
      template_id
      personalisation
    ].freeze

    # Event Bus Gateway receives an event from the Kafka topic and
    # POSTs here to notify the veteran in question that a decision
    # letter is ready for viewing.

    # Eventually this will create a record in the DB for a scheduled
    # job to pick up and *that* will send the email.
    def send_email
      EventBusGateway::DecisionLetters::LetterReadyJob.perform_async(
        participant_id: send_email_params[:participant_id],
        template_id: send_email_params[:template_id],
        personalisation: send_email_params[:personalisation]
      )
    end

    private

    def send_email_params
      params.permit(EMAIL_PARAMS)
    end
  end
end
