# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class VnpPtcpntAddrsFindByPrimaryKeyDataMapper
        def initialize(record:)
          @record = record
        end

        def call
          build_data_object
        end

        private

        def build_data_object
          {
            addrs_one_txt: @record[:addrs_one_txt],
            addrs_two_txt: @record[:addrs_two_txt],
            city_nm: @record[:city_nm],
            cntry_nm: @record[:cntry_nm],
            prvnc_nm: @record[:prvnc_nm],
            zip_prefix_nbr: @record[:zip_prefix_nbr],
            zip_first_suffix_nbr: @record[:zip_first_suffix_nbr],
            email_addrs_txt: @record[:email_addrs_txt]
          }
        end
      end
    end
  end
end
