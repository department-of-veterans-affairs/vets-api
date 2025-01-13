# frozen_string_literal: true

module ClaimsApi
  module V2
    class ReadAllVeteranRepresentativeService
      def data_object(proc_id, records)
        rec = find_record(proc_id, records)

        build_data_object(rec)
      end

      def find_record(proc_id, records)
        records.find { |el| el['procId'] == proc_id}
      end

      def build_data_object(data)
        {
          service_number: data["serviceNumber"],
          insurance_numbers: data['insuranceNumbers'],
          phone_number: data['phoneNumber'],
          claimant_relationship: data['claimantRelationship'],
          poa_code: data['poaCode'],
          organization_name: data['organizationName'],
          representative_first_name: data['representativeFirstName'],
          representative_last_name: data['representativeLastName'],
          representative_title: data['representativeTitle'],
          section_7332_auth: data['section7332Auth'],
          limitation_alcohol: data['limitationAlcohol'],
          limitation_drug_abuse: data['limitationDrugAbuse'],
          limitation_hiv: data['limitationHIV'],
          limitation_sca: data['limitationSCA'],
          change_address_auth: data['changeAddressAuth']
        }
      end
    end
  end
end