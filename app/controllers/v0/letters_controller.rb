require 'common/exceptions/internal/record_not_found'

# frozen_string_literal: true
module V0
  class LettersController < ApplicationController
    def index
      response = service.get_letters
      render json: response,
             serializer: LettersSerializer,
             meta: response.metadata
    end

    def show
      unless EVSS::Letters::Letter::LETTER_TYPES.include? params[:id]
        raise Common::Exceptions::ParameterMissing, 'letter_type', "#{params[:id]} is not a valid letter type"
      end
      response = service.download_letter_by_type(params[:id])
      send_data response,
                filename: "#{params[:id]}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    private

    def service
      EVSS::Letters::ServiceFactory.get_service(user: @current_user, mock_service: Settings.evss.mock_letters)
    end
  end
end
