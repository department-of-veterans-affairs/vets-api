# frozen_string_literal: true
module V0
  class LettersController < ApplicationController
    def index
      response = service.get_letters
      render json: response,
             serializer: LettersSerializer,
             meta: response.metadata
    end

    # :nocov:
    def show
      head :ok
    end
    # :nocov:

    private

    def service
      EVSS::Letters::ServiceFactory.get_service(user: @current_user, mock_service: Settings.evss.mock_letters)
    end
  end
end
