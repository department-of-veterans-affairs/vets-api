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

          # Check frgnPhoneRfrncTxt for international numbers
          # International numbers are stored in frgn_phone_rfrnc_txt instead of phone_nbr
          phone_number = @record[:frgn_phone_rfrnc_txt].presence || @record[:phone_nbr]

          # When auto establishing the POA record domestic or international numbers get saved to the same field
          {
            'phone_nbr' => phone_number
          }
        end
      end
    end
  end
end
