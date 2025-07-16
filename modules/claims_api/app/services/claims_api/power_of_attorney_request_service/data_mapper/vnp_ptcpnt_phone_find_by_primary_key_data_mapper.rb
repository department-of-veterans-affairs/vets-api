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

        def build_data_object
          return [] if @record.blank?

          {
            'phone_nbr' => @record[:phone_nbr]
          }
        end
      end
    end
  end
end
