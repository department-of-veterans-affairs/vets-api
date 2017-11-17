require 'common/exceptions/internal/record_not_found'

# frozen_string_literal: true
module V0
  class LettersController < ApplicationController
    def index
      response = service.get_letters(@current_user)
      render json: response,
             serializer: LettersSerializer
    end

    def download
      unless EVSS::Letters::Letter::LETTER_TYPES.include? params[:id]
        raise Common::Exceptions::ParameterMissing, 'letter_type', "#{params[:id]} is not a valid letter type"
      end
      response = service.download_letter(@current_user, params[:id], request.body.string)
      send_data response,
                filename: "#{params[:id]}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    def beneficiary
      response = service.get_letter_beneficiary(@current_user)
      render json: response,
             serializer: LetterBeneficiarySerializer
    end

    private

    def service
      @service ||= EVSS::Letters::ServiceFactory.get_service(mock_service: Settings.evss.mock_letters)
    end
  end
end
