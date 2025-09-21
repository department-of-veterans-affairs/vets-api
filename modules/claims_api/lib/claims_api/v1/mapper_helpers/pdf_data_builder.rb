# frozen_string_literal: true

module ClaimsApi
  module V1
    module PdfDataBuilder
      # PDF structure paths for building nested hashes
      PDF_PATHS = {
        # Identification section
        identification_info: [:identificationInformation],
        identification_name: %i[identificationInformation name],
        identification_mailing_address: %i[identificationInformation mailingAddress],
        # Change of address section
        change_of_address: [:changeOfAddress],
        change_of_address_dates: %i[changeOfAddress effectiveDates],
        change_of_address_new_address: %i[changeOfAddress newAddress],
        # Homelessness section
        homeless_info: [:homelessInformation],
        homeless_currently: %i[homelessInformation currentlyHomeless],
        homeless_risk: %i[homelessInformation riskOfBecomingHomeless],
        # Claim information section
        claim_info: [:claimInformation],
        # Service information section
        service_info: [:serviceInformation],
        service_most_recent: %i[serviceInformation mostRecentActiveService],
        service_reserves: %i[serviceInformation reservesNationalGuardService],
        service_branch_info: %i[serviceInformation branchOfService]
      }.freeze

      def build_pdf_path(path_key)
        path = PDF_PATHS[path_key]
        raise ArgumentError, "Unknown PDF path: #{path_key}" unless path

        current = @pdf_data[:data][:attributes]
        path.each do |key|
          current[key] ||= {}
          current = current[key]
        end
        current
      end
    end
  end
end
