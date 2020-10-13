# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'evss/letters/download_service'
require 'evss/letters/service'

module Mobile
  module V0
    class LettersController < ApplicationController
      before_action { authorize :evss, :access? }

      # returns list of letters available for a given user. List includes letter display name and letter type
      def index
        render json: Mobile::V0::LettersSerializer.new(@current_user.id, service.get_letters.letters)
      end

      # returns options and info needed to create user form required for benefit letter download
      def beneficiary
        render json: Mobile::V0::LettersBeneficiarySerializer.new(@current_user.id, service.get_letter_beneficiary)
      end

      # returns a pdf of the requested letter type given the user has that letter type available
      def download
        unless EVSS::Letters::Letter::LETTER_TYPES.include? params[:type]
          Raven.tags_context(team: 'va-mobile-app') # tag sentry logs with team name
          raise Common::Exceptions::ParameterMissing, 'letter_type', "#{params[:type]} is not a valid letter type"
        end

        response = download_service.download_letter(params[:type], request.body.string)
        send_data response,
                  filename: "#{params[:type]}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      def service
        @service ||= EVSS::Letters::Service.new(@current_user)
      end

      def download_service
        @download_service ||= EVSS::Letters::DownloadService.new(@current_user)
      end
    end
  end
end
