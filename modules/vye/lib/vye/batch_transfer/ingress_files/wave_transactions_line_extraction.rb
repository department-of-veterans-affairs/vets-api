# frozen_string_literal: true

module Vye
  module BatchTransfer
    module WaveTransactionsLineExtraction
      private

      def initialize(row:)
        super(row:, profile: nil, verifications: nil)

        extract_profile
        extract_verifications
      end

      def extract_profile
        ssn = row[:SSN]
        self.profile = { ssn: }
      end

      def extract_verifications
        transact_date = DateTime.strptime(row[:TRANSACT_DATE], '%y-%m-%d %H:%M:%S.%L')
        act_begin = DateTime.strptime(row[:WAVE_BEGIN_DATE], '%y-%m-%d %H:%M:%S.%L')
        act_end = DateTime.strptime(row[:WAVE_END_DATE], '%y-%m-%d %H:%M:%S.%L')
        number_hours = row[:WAVE_HOURS]
        source_ind = row[:SOURCE_IND]

        self.verifications = { transact_date:, act_begin:, act_end:, number_hours:, source_ind: }
      end

      public

      def records
        raise 'invalid extraction' if [profile, verifications].any?(&:blank?)

        { profile:, verifications: }
      end
    end
  end
end
