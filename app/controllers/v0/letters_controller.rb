# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'evss/letters/download_service'
require 'evss/letters/service'

module V0
  class LettersController < ApplicationController
    service_tag 'letters'
    before_action { authorize :evss, :access_letters? }

    def index
      response = service.get_letters
      render json: LettersSerializer.new(response)
    end

    def download
      unless EVSS::Letters::Letter::LETTER_TYPES.include? params[:id]
        Sentry.set_tags(team: 'benefits-memorial-1') # tag sentry logs with team name
        raise Common::Exceptions::ParameterMissing, 'letter_type', "#{params[:id]} is not a valid letter type"
      end

      response = download_service.download_letter(params[:id], request.body.string)
      send_data response,
                filename: "#{params[:id]}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    def beneficiary
      response = service.get_letter_beneficiary
      render json: LetterBeneficiarySerializer.new(response)
    end

    private

    def service
      EVSS::Letters::Service.new(@current_user)
    end

    def download_service
      EVSS::Letters::DownloadService.new(@current_user)
    end
  end
end
