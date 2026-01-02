# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataGatherer
      class VnpPtcpntPhoneFindByPrimaryKeyDataGatherer
        def initialize(record:)
          @record = record
        end

        def call
          build_data_object
        end

        private

        # The data structure of the data returned from these calls to
        # BEP (BGS) is not uniform. The data returned here is like data[:value]
        def build_data_object
          return {} if @record.blank?

          {
            'phone_nbr' => @record[:phone_nbr]
          }
        end
      end
    end
  end
end
