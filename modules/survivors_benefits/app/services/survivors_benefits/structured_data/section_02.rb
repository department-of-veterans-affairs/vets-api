# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section02
  ##
  # Section II
  # Build and merge the claimant-specific structured data entries.
  #
  # @return [Hash]
  def merge_claimants_id_info
    merge_name_fields(form['claimantFullName'], 'CLAIMANT')
    merge_claimant_address_fields(form['claimantAddress'])
    merge_relationship(form['claimantRelationship'])
    merge_claim_type_fields(form['claims'])

    fields.merge!(y_n_pair(form['claimantIsVeteran'], 'CLAIMANT_VETERAN_Y', 'CLAIMANT_VETERAN_N'))
    primary_phone = { 'contact' => form['claimantPhone'], 'countryCode' => form.dig('claimantAddress', 'country') }
    fields.merge!(
      {
        'CLAIMANT_SSN' => form['claimantSocialSecurityNumber'],
        'CLAIMANT_DOB' => format_date(form['claimantDateOfBirth']),
        'PHONE_NUMBER' => primary_phone['contact'],
        'INT_PHONE_NUMBER' => international_phone_number(form, primary_phone, 'claimantInternationalPhone'),
        'EMAIL' => form['claimantEmail']
      }
    )
  end

  ##
  # Build and merge the claimant address fields
  #
  # @param claimant_address [Hash]
  # @return [Hash]
  def merge_claimant_address_fields(claimant_address)
    if claimant_address.is_a?(Hash)
      fields.merge!(
        {
          'CLAIMANT_ADDRESS_FULL_BLOCK' => build_address_block(claimant_address),
          'CLAIMANT_ADDRESS_LINE1' => claimant_address['street'],
          'CLAIMANT_ADDRESS_LINE2' => claimant_address['street2'],
          'CLAIMANT_ADDRESS_CITY' => claimant_address['city'],
          'CLAIMANT_ADDRESS_STATE' => claimant_address['state'],
          'CLAIMANT_ADDRESS_COUNTRY' => claimant_address['country'],
          'CLAIMANT_ADDRESS_ZIP5' => claimant_address['postalCode']
        }
      )
    end
  end

  ##
  # Build and merge the claimant relationship fields
  #
  # @param relationship [String]
  # @return [Hash]
  def merge_relationship(relationship)
    if relationship.present?
      fields.merge!(
        {
          'RELATIONSHIP_SURVIVING_SPOUSE' => relationship == 'SURVIVING_SPOUSE',
          'RELATIONSHIP_CHILD' => relationship == 'CHILD_18-23_IN_SCHOOL',
          'RELATIONSHIP_CUSTODIAN' => relationship == 'CUSTODIAN_FILING_FOR_CHILD_UNDER_18',
          'RELATIONSHIP_HELPLESSCHILD' => relationship == 'HELPLESS_ADULT_CHILD'
        }
      )
    end
  end

  ##
  # Build and merge the claim type fields based on the claims hash
  #
  # @param claims [Hash]
  # @return [Hash]
  def merge_claim_type_fields(claims)
    if claims.is_a?(Hash)
      fields.merge!(
        {
          'CLAIM_TYPE_DIC' => claims['DIC'] || false,
          'CLAIM_TYPE_SURVIVOR_PENSION' => claims['survivorsPension'] || false,
          'CLAIM_TYPE_ACCRUED_BENEFITS' => claims['accruedBenefits'] || false
        }
      )
    end
  end
end
