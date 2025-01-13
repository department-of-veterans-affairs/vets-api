# frozen_string_literal: true

module ClaimsApi
  module V2
    class VnpPctpntAddrsFindByPrimaryKeyService
      def data_object(record)
        build_data_object(record)
      end

      def build_data_object(data)
        {
          addrs_one_txt: data[:addrs_one_txt],
          addrs_two_txt: data[:addrs_two_txt],
          city_nm: data[:city_nm],
          cntry_nm: data[:cntry_nm],
          prvnc_nm: data[:prvnc_nm],
          zip_prefix_nbr: data[:zip_first_suffix_nbr],
          zip_first_suffix_nbr: data[:zip_first_suffix_nbr],
          email_addrs_txt: data[:email_addrs_txt]
        }
      end
    end
  end
end