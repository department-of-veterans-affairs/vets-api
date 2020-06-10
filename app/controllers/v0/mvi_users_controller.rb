# frozen_string_literal: true

module V0
  class MviUsersController < ApplicationController

    def update
      # Caller must be using proxy add in order to complete intent to file or disability compensation claim
      form_id = params[:id]
      if [VA0996::FORM_ID, VA526ez::FORM_ID].exclude?(form_id)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: "Action is prohibited with id parameter #{form_id}",
          source: 'MviUsersController'
        )
      end

      if @current_user.participant_id.nil?
        # Add person to MVI if missing participant_id (no matter if birls_id present or absent)
        add_response = @current_user.mvi.mvi_add_person
        raise add_response.error unless add_response.ok?

        # What does FE want here, it's a positive response on a post so the response would traditionally
        # contain the data describing the action result
        render json: { "message": add_response }

      elsif @current_user.birls_id.nil?

        # Error if birls_id is empty with known participant_id
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'No birls_id while participant_id present',
          source: 'InProgressFormsController'
        )

      render
      end
    end
  end
end
