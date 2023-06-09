# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'evss/letters/download_service'
require 'evss/letters/service'
require 'lighthouse/letters_generator/service'

module Mobile
  module V0
    class LettersController < ApplicationController
      before_action do
        if Flipper.enabled?(:mobile_lighthouse_letters, @current_user)
          authorize :lighthouse, :access?
        else
          authorize :evss, :access?
        end
      end

      # returns list of letters available for a given user. List includes letter display name and letter type
      def index
        response = if Flipper.enabled?(:mobile_lighthouse_letters, @current_user)
                     lighthouse_service.get_eligible_letter_types(icn)[:letters]
                   else
                     evss_service.get_letters.letters
                   end
        render json: Mobile::V0::LettersSerializer.new(@current_user, response)
      end

      # returns options and info needed to create user form required for benefit letter download
      def beneficiary
        response = if Flipper.enabled?(:mobile_lighthouse_letters, @current_user)
                     letter_info_adapter.parse(lighthouse_service.get_benefit_information(icn))
                   else
                     evss_service.get_letter_beneficiary
                   end
        render json: Mobile::V0::LettersBeneficiarySerializer.new(@current_user, response)
      end

      # returns a pdf of the requested letter type given the user has that letter type available
      def download
        response = if Flipper.enabled?(:mobile_lighthouse_letters, @current_user)
                     lighthouse_service.download_letter(icn, params[:type])
                   else
                     unless EVSS::Letters::Letter::LETTER_TYPES.include? params[:type]
                       Raven.tags_context(team: 'va-mobile-app') # tag sentry logs with team name
                       raise Common::Exceptions::ParameterMissing, 'letter_type',
                             "#{params[:type]} is not a valid letter type"
                     end

                     download_service.download_letter(params[:type], request.body.string)
                   end
        StatsD.increment('mobile.letters.download.type', tags: ["type:#{params[:type]}"], sample_rate: 1.0)
        send_data response,
                  filename: "#{params[:type]}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      def icn
        @current_user.icn
      end

      def letter_info_adapter
        Mobile::V0::Adapters::LetterInfo.new
      end

      def lighthouse_service
        Lighthouse::LettersGenerator::Service.new
      end

      def evss_service
        @service ||= EVSS::Letters::Service.new(@current_user)
      end

      def download_service
        @download_service ||= EVSS::Letters::DownloadService.new(@current_user)
      end
    end
  end
end
