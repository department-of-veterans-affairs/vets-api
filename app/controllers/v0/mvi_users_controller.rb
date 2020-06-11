# frozen_string_literal: true

module V0
  class MviUsersController < ApplicationController
    before_action { authorize :mvi, :missing_critical_ids? }

    def submit
      # Caller must be using proxy add in order to complete Intent to File or Disability Compensation forms
      form_id = params[:id]
      if [FormProfiles::VA0996::FORM_ID, VA526ez::FORM_ID].exclude?(form_id)
        raise Common::Exceptions::Forbidden.new(
          detail: "Action is prohibited with id parameter #{form_id}",
          source: 'MviUsersController'
        )
      end

      # Scenario indicates serious problems with user data
      if @current_user.birls_id.nil? && @current_user.participant_id.present?
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'No birls_id while participant_id present',
          source: 'MviUsersController'
        )
      end

      # Add user to MVI
      add_response = @current_user.mvi.mvi_add_person
      raise add_response.error unless add_response.ok?

      render json: { "message": add_response }
    end
  end
end
