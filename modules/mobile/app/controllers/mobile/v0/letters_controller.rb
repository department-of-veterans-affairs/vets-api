# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'evss/letters/download_service'
require 'evss/letters/service'

module Mobile
  module V0
    class LettersController < ApplicationController
      before_action { authorize :evss, :access? }

      def letters
        service_response = EVSS::Letters::Service.new(@current_user).get_letters
        response_template = OpenStruct.new
        response_template.id = @current_user.id
        response_template.letters = service_response.letters
        response_template.full_name = service_response.full_name
        render json: Mobile::V0::LettersSerializer.new(response_template)
      end

      def beneficiary
        service_response = EVSS::Letters::Service.new(@current_user).get_letter_beneficiary
        response_template = OpenStruct.new
        response_template.id = @current_user.id
        response_template.benefit_information = service_response.benefit_information
        response_template.military_service = service_response.military_service
        render json: Mobile::V0::LettersBeneficiarySerializer.new(response_template)
      end

      def download
        unless EVSS::Letters::Letter::LETTER_TYPES.include? params[:id]
          Raven.tags_context(team: 'va-mobile-app') # tag sentry logs with team name
          raise Common::Exceptions::ParameterMissing, 'letter_type', "#{params[:id]} is not a valid letter type"
        end

        response = EVSS::Letters::DownloadService.new(@current_user).download_letter(params[:id], request.body.string)
        send_data response,
                  filename: "#{params[:id]}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  end
end
