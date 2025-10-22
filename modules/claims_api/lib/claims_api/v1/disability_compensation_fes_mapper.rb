# frozen_string_literal: true

module ClaimsApi
  module V1
    class DisabilityCompensationFesMapper
      IGNORED_DISABILITY_FIELDS = %i[serviceRelevance secondaryDisabilities].freeze

      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = auto_claim&.form_data&.deep_symbolize_keys
        @fes_claim = {}
      end

      def map_claim
        claim_attributes

        wrap_in_request_structure
      end

      private

      def claim_attributes
        disabilities
      end

      # a 'disability' is required via the schema
      # 'disabilityActionType' & 'name' are required via the schema
      def disabilities
        disablities_data = flatten_disabilities(@data[:disabilities])
        @fes_claim[:disabilities] = disablities_data.map do |disability|
          transform_disability_values!(disability.deep_dup)
        end
      end

      def transform_disability_values!(disability)
        %i[diagnosticCode classificationCode ratedDisabilityId specialIssues].each do |field|
          disability.delete(field) if disability[field].blank?
        end

        begin_date = disability[:approximateBeginDate]
        disability[:approximateBeginDate] = make_date_object(begin_date, begin_date.length) if begin_date.present?

        disability.except(*IGNORED_DISABILITY_FIELDS)
      end

      def flatten_disabilities(disabilities_array)
        disabilities_array.flat_map do |disability|
          primary_disability = disability.dup
          secondaries = primary_disability.delete(:secondaryDisabilities) || []

          list = []
          list << primary_disability unless primary_disability[:disabilityActionType] == 'NONE'
          list.concat(secondaries.map { |s| s.dup.merge(disabilityActionType: 'NEW') })

          list
        end
      end

      def make_date_object(date, date_length)
        year, month, day = regex_date_conversion(date)
        return if year.nil? || date_length.nil?

        if date_length == 4
          { year: }
        elsif date_length == 7
          { month:, year: }
        else
          { year:, month:, day: }
        end
      end

      def regex_date_conversion(date)
        if date.present?
          date_match = date.match(/^(?:(?<year>\d{4})(?:-(?<month>\d{2}))?(?:-(?<day>\d{2}))*|(?<month>\d{2})?(?:-(?<day>\d{2}))?-?(?<year>\d{4}))$/) # rubocop:disable Layout/LineLength
          date_match&.values_at(:year, :month, :day)
        end
      end

      def wrap_in_request_structure
        {
          data: {
            serviceTransactionId: @auto_claim.auth_headers['va_eauth_service_transaction_id'],
            veteranParticipantId: extract_veteran_participant_id,
            claimantParticipantId: extract_claimant_participant_id,
            form526: @fes_claim
          }
        }
      end

      def extract_veteran_participant_id
        # Try auth_headers first, then fall back to other sources
        @auto_claim.auth_headers&.dig('va_eauth_pid') ||
          @auto_claim.auth_headers&.dig('participant_id')
      end

      def extract_claimant_participant_id
        # For dependent claims, use dependent participant ID
        if @auto_claim.auth_headers&.dig('dependent', 'participant_id').present?
          @auto_claim.auth_headers.dig('dependent', 'participant_id')
        else
          # Otherwise, claimant is the veteran
          extract_veteran_participant_id
        end
      end
    end
  end
end
