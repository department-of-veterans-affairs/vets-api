# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class VeteranDataMapper
        def initialize(veteran:)
          @veteran = veteran
        end

        def call
          build_data_object
        end

        private

        def build_data_object
          return [] if @veteran.blank?

          {
            name: "#{@veteran.first_name} #{@veteran.last_name}",
            ssn: @veteran.ssn,
            file_number: @veteran.file_number,
            date_of_birth: @veteran.birth_date
          }
        end
      end
    end
  end
end
