# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataMapper
      class ClaimantDataMapper
        def initialize(claimant:)
          @claimant = claimant
        end

        def call
          build_data_object
        end

        private

        def build_data_object
          return [] if @claimant.blank?

          {
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> 2d0b7b7aa2 (Merges in upstream, fixes conflicts and cleans up requests to match)
            'name' => "#{@claimant.first_name} #{@claimant.last_name}",
            'ssn' => @claimant.ssn,
            'file_number' => @claimant.birls_id || @claimant.mpi.birls_id,
            'date_of_birth' => @claimant.birth_date
<<<<<<< HEAD
=======
            name: "#{@claimant.first_name} #{@claimant.last_name}",
            ssn: @claimant.ssn,
            file_number: @claimant.birls_id || @claimant.mpi.birls_id,
            date_of_birth: @claimant.birth_date
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
=======
>>>>>>> 2d0b7b7aa2 (Merges in upstream, fixes conflicts and cleans up requests to match)
          }
        end
      end
    end
  end
end
