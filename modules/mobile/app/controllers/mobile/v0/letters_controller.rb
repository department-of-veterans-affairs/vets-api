# frozen_string_literal: true

require 'common/exceptions/record_not_found'
require 'lgy/service'
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
      COE_STATUSES = %w[AVAILABLE ELIGIBLE].freeze
      COE_LETTER_TYPE = 'certificate_of_eligibility_home_loan'
      COE_APP_VERSION = '2.58.0'

      before_action { authorize :lighthouse, :access? }

      before_action :validate_format!, only: %i[download]
      before_action :validate_letter_type!, only: %i[download]
      after_action :increment_download_counter, only: %i[download], if: -> { response.successful? }

      # returns list of letters available for a given user. List includes letter display name and letter type
      def index
        letters = lighthouse_service.get_eligible_letter_types(icn)[:letters]
        response = letters.filter_map do |letter|
          # The following letters need to be filtered out due to outdated content
          next if FILTERED_LETTER_TYPES.include? letter[:letterType]

          Mobile::V0::Letter.new(letter_type: letter[:letterType], name: letter[:name])
        end
        response.append(get_coe_letter_type).compact! if Flipper.enabled?(:mobile_coe_letter_use_lgy_service,
                                                                          @current_user) && coe_app_version?

        render json: Mobile::V0::LettersSerializer.new(@current_user, response.select(&:displayable?).sort_by(&:name))
      end

      # returns options and info needed to create user form required for benefit letter download
      def beneficiary
        response = letter_info_adapter.parse(@current_user.uuid, lighthouse_service.get_benefit_information(icn))

        render json: Mobile::V0::LettersBeneficiarySerializer.new(response)
      end

      # returns a pdf or json representation of the requested letter type given the user has that letter type available
      def download
        if params[:type] == COE_LETTER_TYPE
          begin
            StatsD.increment('mobile.letters.coe_status.download_total')
            response = lgy_service.get_coe_file.body
            StatsD.increment('mobile.letters.coe_status.download_success')
          rescue => e
            StatsD.increment('mobile.letters.coe_status.download_failure')
            Rails.logger.error('LGY COE letter download failed', error: e.message)
            raise e
          end
        else
          if params[:format] == 'json'
            letter = lighthouse_service.get_letter(icn, params[:type], download_options_hash)
            return render json: Mobile::V0::LetterSerializer.new(current_user.uuid, letter)
          end

          response = download_lighthouse_letters(params)
        end

        send_data response, filename: "#{params[:type]}.pdf", type: 'application/pdf', disposition: 'attachment'
      end

      private

      def get_coe_letter_type
        StatsD.increment('mobile.letters.coe_status.total')

        coe_status = lgy_service.coe_status

        increment_coe_counter(coe_status)

        if coe_status[:status].in?(COE_STATUSES)
          Mobile::V0::Letter.new(
            letter_type: COE_LETTER_TYPE, name: 'Certificate of Eligibility for Home Loan Letter',
            reference_number: coe_status[:reference_number], coe_status: coe_status[:status]
          )
        end
      rescue => e
        # log the error but don't prevent other letters from being shown
        StatsD.increment('mobile.letters.coe_status.failure')
        Rails.logger.error('LGY COE status check failed', error: e.message)
        nil
      end

      def download_lighthouse_letters(params)
        lighthouse_service.download_letter({ icn: }, params[:type], download_options_hash)
      end

      def icn
        @current_user.icn
      end

      def validate_letter_type!
        unless lighthouse_service.valid_type?(params[:type]) || (
          Flipper.enabled?(:mobile_coe_letter_use_lgy_service,
                           @current_user) && params[:type] == COE_LETTER_TYPE
        )
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

      def increment_coe_counter(coe_status)
        if coe_status[:status] == 'ELIGIBLE'
          StatsD.increment('mobile.letters.coe_status.eligible')
        elsif coe_status[:status] == 'AVAILABLE'
          StatsD.increment('mobile.letters.coe_status.available')
        end
      end

      # body params appear in the params hash in specs but not in actual requests
      def download_options_hash
        body_string = request.body.string
        return {} if body_string.blank?

        body_params = JSON.parse(body_string)
        body_params.keep_if { |k, _| k.in? DOWNLOAD_PARAMS }
      end

      def coe_app_version?
        # Treat missing version as an old version
        return false if request.headers['App-Version'].nil?

        # Treat malformed version as an old version
        begin
          version = Gem::Version.new(request.headers['App-Version'])
        rescue ArgumentError
          return false
        end

        version > Gem::Version.new(COE_APP_VERSION)
      end

      def letter_info_adapter
        Mobile::V0::Adapters::LetterInfo.new
      end

      def lighthouse_service
        Lighthouse::LettersGenerator::Service.new
      end

      def lgy_service
        LGY::Service.new(edipi: @current_user.edipi, icn: @current_user.icn)
      end
    end
  end
end
