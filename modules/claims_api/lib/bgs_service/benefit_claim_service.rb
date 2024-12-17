# frozen_string_literal: true

module ClaimsApi
  class BenefitClaimService < ClaimsApi::LocalBGS
    def bean_name
      'BenefitClaimServiceBean/BenefitClaimWebService'
    end

    def update_benefit_claim(options = {})
      builder = Nokogiri::XML::Builder.new do
        benefitClaimUpdateInput do
          fileNumber options[:file_number]
          payeeCode options[:payee_code]
          dateOfClaim options[:date_of_claim]
          disposition
          sectionUnitNo '1911'
          folderWithClaim
          claimantSsn options[:claimant_ssn]
          powerOfAttorney options[:power_of_attorney]
          benefitClaimType options[:benefit_claim_type]
          oldEndProductCode options[:old_end_product_code]
          newEndProductLabel options[:new_end_product_label]
          oldDateOfClaim options[:old_date_of_claim]
          allowPoaAccess options[:allow_poa_access] if options[:allow_poa_access]
          allowPoaCadd options[:allow_poa_cadd] if options[:allow_poa_cadd]
        end
      end

      body = builder_to_xml(builder)

      make_request(endpoint: bean_name, action: 'updateBenefitClaim', body:)
    end
  end
end
