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
<<<<<<< HEAD
            'name' => "#{@veteran.first_name} #{@veteran.last_name}",
            'ssn' => @veteran.ssn,
            'file_number' => @veteran&.birls_id || @veteran&.mpi&.birls_id,
            'date_of_birth' => @veteran.birth_date
=======
            name: "#{@veteran.first_name} #{@veteran.last_name}",
            ssn: @veteran.ssn,
            file_number: @veteran&.birls_id || @veteran&.mpi&.birls_id,
            date_of_birth: @veteran.birth_date
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
          }
        end
      end
    end
  end
end
