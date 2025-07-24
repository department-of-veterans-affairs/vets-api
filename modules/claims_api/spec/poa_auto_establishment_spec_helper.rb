# frozen_string_literal: true

RSpec.shared_context 'shared POA auto establishment data' do
  let(:data) do
    {
      'name' => 'Ralph Lee',
      'ssn' => '796378782',
      'file_number' => '123456',
      'date_of_birth' => '19481030',
      'service_number' => '123678453',
      'insurance_numbers' => '1234567890',
      'phone_number' => '5555551234',
      'claimant_relationship' => 'Spouse',
      'poa_code' => '083',
      'organization_name' => 'DISABLED AMERICAN VETERANS',
      'representativeLawFirmOrAgencyName' => nil,
      'representative_first_name' => 'John',
      'representative_last_name' => 'Doe',
      'representative_title' => nil,
      'section_7332_auth' => 'true',
      'limitation_alcohol' => 'true',
      'limitation_drug_abuse' => 'true',
      'limitation_hiv' => 'true',
      'limitation_sca' => 'true',
      'change_address_auth' => 'true',
      'addrs_one_txt' => '2719 Hyperion Ave',
      'addrs_two_txt' => 'Apt 2',
      'city_nm' => 'Los Angeles',
      'cntry_nm' => 'USA',
      'postal_cd' => 'CA',
      'zip_prefix_nbr' => '92264',
      'zip_first_suffix_nbr' => '0200',
      'email_addrs_txt' => nil,
      'claimant' => {
        'claimant_id' => '1013093331V548481',
        'name' => 'Wally Morrell',
        'ssn' => '700052257',
        'file_number' => '700052257',
        'date_of_birth' => '19581218',
        'addrs_one_txt' => '123 Main St',
        'addrs_two_txt' => 'Apt 3',
        'city_nm' => 'Boston',
        'cntry_nm' => 'USA',
        'postal_cd' => 'MA',
        'zip_prefix_nbr' => '02110',
        'zip_first_suffix_nbr' => '1000',
        'email_addrs_txt' => nil,
        'phone_nbr' => '5555559876'
      },
      'registration_number' => '12345678'
    }
  end

  let(:form_data) do
    {
      'data' => {
        'attributes' => {
          'veteran' => {
            'address' => {
              'addressLine1' => '2719 Hyperion Ave',
              'addressLine2' => 'Apt 2',
              'city' => 'Los Angeles',
              'stateCode' => 'CA',
              'countryCode' => 'US',
              'zipCode' => '92264',
              'zipCodeSuffix' => '0200'
            },
            'phone' => {
              'countryCode' => nil,
              'areaCode' => '555',
              'phoneNumber' => '5551234'
            },
            'email' => nil,
            'serviceNumber' => '123678453',
            'insuranceNumber' => '1234567890'
          },
          'serviceOrganization' => {
            'poaCode' => '083',
            'registrationNumber' => '12345678',
            'jobTitle' => nil
          },
          'recordConsent' => true,
          'consentLimits' => %w[
            DRUG_ABUSE
            ALCOHOLISM
            HIV
            SICKLE_CELL
          ],
          'consentAddressChange' => true,
          'claimant' => {
            'claimantId' => '1013093331V548481',
            'address' => {
              'addressLine1' => '123 Main St',
              'addressLine2' => 'Apt 3',
              'city' => 'Boston',
              'stateCode' => 'MA',
              'countryCode' => 'US',
              'zipCode' => '02110',
              'zipCodeSuffix' => '1000'
            },
            'phone' => {
              'countryCode' => nil,
              'areaCode' => '555',
              'phoneNumber' => '5559876'
            },
            'email' => nil,
            'relationship' => 'Spouse'
          }
        }
      }
    }
  end

  let(:validated_form_data) do
    {
      'data' => {
        'attributes' => {
          'veteran' => {
            'address' => {
              'addressLine1' => '2719 Hyperion Ave',
              'addressLine2' => 'Apt 2',
              'city' => 'Los Angeles',
              'stateCode' => 'CA',
              'countryCode' => 'US',
              'zipCode' => '92264',
              'zipCodeSuffix' => '0200'
            },
            'phone' => {
              'areaCode' => '555',
              'phoneNumber' => '5551234'
            },
            'serviceNumber' => '123678453',
            'insuranceNumber' => '1234567890'
          },
          'serviceOrganization' => {
            'poaCode' => '083',
            'registrationNumber' => '12345678'
          },
          'recordConsent' => true,
          'consentLimits' => %w[
            DRUG_ABUSE
            ALCOHOLISM
            HIV
            SICKLE_CELL
          ],
          'consentAddressChange' => true,
          'claimant' => {
            'claimantId' => '1013093331V548481',
            'address' => {
              'addressLine1' => '123 Main St',
              'addressLine2' => 'Apt 3',
              'city' => 'Boston',
              'stateCode' => 'MA',
              'countryCode' => 'US',
              'zipCode' => '02110',
              'zipCodeSuffix' => '1000'
            },
            'phone' => {
              'areaCode' => '555',
              'phoneNumber' => '5559876'
            },
            'relationship' => 'Spouse'
          }
        }
      }
    }
  end

  let(:veteran) do
    OpenStruct.new(
      icn: '1012861229V078999',
      first_name: 'Ralph',
      last_name: 'Lee',
      middle_name: nil,
      birls_id: '796378782',
      birth_date: '1948-10-30',
      loa: { current: 3, highest: 3 },
      edipi: nil,
      ssn: '796378782',
      participant_id: '600043284',
      mpi: OpenStruct.new(
        icn: '1012861229V078999',
        profile: OpenStruct.new(ssn: '796378782')
      )
    )
  end
end
