# frozen_string_literal: true

module V0
  # Formerly MviUsersController
  class MPIUsersController < ApplicationController
    service_tag 'identity'
    before_action { authorize :mpi, :access_add_person_proxy? }
    before_action :validate_form!
    before_action :validate_user_ids!

    ALLOWED_FORM_IDS = ['21-0966', FormProfiles::VA526ez::FORM_ID].freeze

    def submit
      add_response = MPIData.for_user(@current_user.identity).add_person_proxy

      if add_response.ok?
        render json: { message: 'Success' }
      else
        error_message = 'MPI add_person_proxy error'
        Rails.logger.error('[V0][MPIUsersController] submit error', error_message:)

        render(json: { errors: [{ error_message: }] }, status: :unprocessable_entity)
      end
    end

    private

    def validate_form!
      form_id = params[:id]
      return if ALLOWED_FORM_IDS.include?(form_id)

      raise Common::Exceptions::Forbidden.new(
        detail: "Action is prohibited with id parameter #{form_id}",
        source: 'MPIUsersController'
      )
    end

    def validate_user_ids!
      return unless @current_user.birls_id.nil? && @current_user.participant_id.present?

      raise Common::Exceptions::UnprocessableEntity.new(
        detail: 'No birls_id while participant_id present',
        source: 'MPIUsersController'
      )
    end
  end
end
