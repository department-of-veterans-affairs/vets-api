# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataGatherer
      class VnpPtcpntAddrsFindByPrimaryKeyDataGatherer
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
            'addrs_one_txt' => @record[:addrs_one_txt],
            'addrs_two_txt' => @record[:addrs_two_txt],
            'city_nm' => @record[:city_nm],
            'cntry_nm' => @record[:cntry_nm],
            'postal_cd' => @record[:postal_cd], # this looks like postal code but is actually the stateCode
            'zip_prefix_nbr' => @record[:zip_prefix_nbr],
            'zip_first_suffix_nbr' => @record[:zip_first_suffix_nbr],
            'email_addrs_txt' => @record[:email_addrs_txt]
          }
        end
      end
    end
  end
end
