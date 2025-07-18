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
            'name' => "#{@claimant.first_name} #{@claimant.last_name}",
            'ssn' => @claimant.ssn,
            'file_number' => @claimant.birls_id || @claimant.mpi.birls_id,
            'date_of_birth' => @claimant.birth_date
          }
        end
      end
    end
  end
end
