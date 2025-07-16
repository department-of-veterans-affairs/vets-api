# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class VnpPtcpntPhoneFindByPrimaryKeyDataMapper
        def initialize(record:)
          @record = record
        end

        def call
          build_data_object
        end

        private

<<<<<<< HEAD
        # The data structure of the data returned from these calls to
        # BEP (BGS) is not uniform. The data returned here is like data[:value]
=======
>>>>>>> 1e8d0ec948 (WIP)
        def build_data_object
          return [] if @record.blank?

          {
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
            'phone_nbr' => @record[:phone_nbr]
=======
            phone_number: @record[:phone_number]
>>>>>>> 1e8d0ec948 (WIP)
=======
            phone_nbr: @record[:phone_nbr]
>>>>>>> 265ee2cf48 (API-43735-gather-data-for-poa-accept-phone-3)
=======
            'phone_nbr' => @record[:phone_nbr]
>>>>>>> 2d0b7b7aa2 (Merges in upstream, fixes conflicts and cleans up requests to match)
          }
        end
      end
    end
  end
<<<<<<< HEAD
<<<<<<< HEAD
end
=======
end
>>>>>>> 1e8d0ec948 (WIP)
=======
end
>>>>>>> 265ee2cf48 (API-43735-gather-data-for-poa-accept-phone-3)
