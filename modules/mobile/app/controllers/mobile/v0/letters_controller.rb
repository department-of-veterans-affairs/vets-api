# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'evss/letters/download_service'
require 'evss/letters/service'
require 'lighthouse/letters_generator/service'

module Mobile
  module V0
    class LettersController < ApplicationController
      DOWNLOAD_PARAMS = %w[
        militaryService
        serviceConnectedDisabilities
        serviceConnectedEvaluation
        nonServiceConnectedPension
        monthlyAward
        unemployable
        specialMonthlyCompensation
        adaptedHousing
        chapter35Eligibility
        deathResultOfDisability
        survivorsAward
      ].freeze
      DOWNLOAD_FORMATS = %w[json pdf].freeze
      FILTERED_LETTER_TYPES = %w[
        medicare_partd
        minimum_essential_coverage
      ].freeze

      before_action do
        if Flipper.enabled?(:mobile_lighthouse_letters, @current_user)
          authorize :lighthouse, :access?
        else
          authorize :evss, :access?
        end
      end
      before_action :validate_format!, only: %i[download]
      before_action :validate_letter_type!, only: %i[download]
      after_action :increment_download_counter, only: %i[download], if: -> { response.successful? }

      # returns list of letters available for a given user. List includes letter display name and letter type
      def index
        response = if Flipper.enabled?(:mobile_lighthouse_letters, @current_user)
                     letters = lighthouse_service.get_eligible_letter_types(icn)[:letters]
                     letters.filter_map do |letter|
                       # The following letters need to be filtered out due to outdated content
                       next if FILTERED_LETTER_TYPES.include? letter[:letterType]

                       Mobile::V0::Letter.new(letter_type: letter[:letterType], name: letter[:name])
                     end
                   else
                     letters = evss_service.get_letters.letters
                     letters.filter_map do |letter|
                       # The following letters need to be filtered out due to outdated content
                       next if FILTERED_LETTER_TYPES.include? letter.letter_type

                       Mobile::V0::Letter.new(letter_type: letter.letter_type, name: letter.name)
                     end
                   end

        render json: Mobile::V0::LettersSerializer.new(@current_user, response.select(&:displayable?).sort_by(&:name))
      end

      # returns options and info needed to create user form required for benefit letter download
      def beneficiary
        response = if Flipper.enabled?(:mobile_lighthouse_letters, @current_user)
                     letter_info_adapter.parse(@current_user.uuid, lighthouse_service.get_benefit_information(icn))
                   else
                     evss_service.get_letter_beneficiary
                   end
        render json: Mobile::V0::LettersBeneficiarySerializer.new(@current_user, response)
      end

      # returns a pdf or json representation of the requested letter type given the user has that letter type available
      def download
        if params[:format] == 'json'
          letter = lighthouse_service.get_letter(icn, params[:type], download_options_hash)
          return render json: Mobile::V0::LetterSerializer.new(current_user.uuid, letter)
        end

        response = if Flipper.enabled?(:mobile_lighthouse_letters, @current_user)
                     download_lighthouse_letters(params)
                   else
                     unless EVSS::Letters::Letter::LETTER_TYPES.include? params[:type]
                       Sentry.set_tags(team: 'va-mobile-app') # tag sentry logs with team name
                       raise Common::Exceptions::ParameterMissing, 'letter_type',
                             "#{params[:type]} is not a valid letter type"
                     end

                     download_service.download_letter(params[:type], request.body.string)
                   end
        send_data response,
                  filename: "#{params[:type]}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      private

      def download_lighthouse_letters(params)
        lighthouse_service.download_letter({ icn: }, params[:type], download_options_hash)
      end

      def icn
        @current_user.icn
      end

      def validate_letter_type!
        unless lighthouse_service.valid_type?(params[:type])
          raise Common::Exceptions::BadRequest.new(
            {
              detail: "Letter type of #{params[:type]} is not one of the expected options",
              source: self.class.name
            }
          )
        end
      end

      def validate_format!
        if params[:format].present? && !params[:format].in?(DOWNLOAD_FORMATS)
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: "Format #{params[:format]} not in #{DOWNLOAD_FORMATS}",
            source: 'Mobile::V0::LettersController'
          )
        end
      end

      def increment_download_counter
        file_format = params[:format] || 'pdf'
        StatsD.increment(
          'mobile.letters.download.type',
          tags: ["type:#{params[:type]}", "format:#{file_format}"],
          sample_rate: 1.0
        )
      end

      # body params appear in the params hash in specs but not in actual requests
      def download_options_hash
        body_string = request.body.string
        return {} if body_string.blank?

        body_params = JSON.parse(body_string)
        body_params.keep_if { |k, _| k.in? DOWNLOAD_PARAMS }
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
