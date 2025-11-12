# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataGatherer
      class ReadAllVeteranRepresentativeDataGatherer
        def initialize(proc_id:, records:)
          @proc_id = proc_id
          @records = records
        end

        def call
          record = extract_record_by_proc_id

          build_data_object(record)
        end

        private

        def extract_record_by_proc_id
          @records.find { |record| record['procId'] == @proc_id }
        end

        # The data structure of the data returned from these calls to
        # BEP (BGS) is not uniform. The data returned here is like data['value']
        def build_data_object(data)
          return {} if data.nil?

          {
            'service_number' => data['serviceNumber'],
            'insurance_numbers' => data['insuranceNumbers'],
            'phone_number' => data['phoneNumber'],
            'claimant_relationship' => data['claimantRelationship'],
            'poa_code' => data['poaCode'],
            'organization_name' => data['organizationName'],
            'representativeLawFirmOrAgencyName' => data['representativeLawFirmOrAgencyName'],
            'representative_first_name' => data['representativeFirstName'],
            'representative_last_name' => data['representativeLastName'],
            'representative_title' => data['representativeTitle'],
            'section_7332_auth' => data['section7332Auth'],
            'limitation_alcohol' => data['limitationAlcohol'],
            'limitation_drug_abuse' => data['limitationDrugAbuse'],
            'limitation_hiv' => data['limitationHIV'],
            'limitation_sca' => data['limitationSCA'],
            'change_address_auth' => data['changeAddressAuth']
          }
        end
      end
    end
  end
end
