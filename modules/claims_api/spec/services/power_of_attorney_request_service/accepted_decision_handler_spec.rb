# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler do
  subject { described_class.new(proc_id:, poa_code:, registration_number:, metadata:, veteran:, claimant:) }

  let(:clazz) { described_class }
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
  let(:proc_id) { '3866592' }
  let(:poa_code) { '083' }
  let(:registration_number) { '123456783' }
  let(:individual_type) { '2122a' }
  let(:organization_type) { '2122' }

  context 'for a valid decide request' do
    let(:proc_id) { '3866592' }
    let(:poa_code) { '083' }
    let(:claimant) do
      OpenStruct.new(
        icn: '1013093331V548481',
        first_name: 'Wally',
        last_name: 'Morell',
        middle_name: nil,
        birth_date: '1948-10-30',
        loa: { current: 3, highest: 3 },
        edipi: nil,
        ssn: '796378782',
        participant_id: '600264235',
        mpi: OpenStruct.new(
          icn: '1013093331V548481',
          profile: OpenStruct.new(ssn: '796378782'),
          birls_id: '796378782'
        )
      )
    end
    let(:metadata) do
      {
        'veteran' => { 'vnp_mail_id' => '157252', 'vnp_email_id' => '157251', 'vnp_phone_id' => '111641',
                       'phone_data' => { 'countryCode' => '1', 'areaCode' => '555', 'phoneNumber' => '5551234' } },
        'claimant' => { 'vnp_mail_id' => '157253', 'vnp_email_id' => '157254', 'vnp_phone_id' => '111642',
                        'phone_data' => { 'countryCode' => '1', 'areaCode' => '555', 'phoneNumber' => '5559876' } }
      }
    end
    let(:returned_data) do
      { 'data' =>
        { 'attributes' =>
          { 'veteran' => {
              'address' => { 'addressLine1' => '2719 Hyperion Ave', 'addressLine2' => 'Apt 2',
                             'city' => 'Los Angeles', 'stateCode' => 'CA', 'countryCode' => 'US',
                             'zipCode' => '92264', 'zipCodeSuffix' => '0200' },
              'phone' => { 'countryCode' => '1', 'areaCode' => '555', 'phoneNumber' => '5551234' },
              'serviceNumber' => '123456783'
            },
            'representative' => { 'poaCode' => '067', 'type' => 'ATTORNEY', 'registrationNumber' => '123456783' },
            'recordConsent' => true, 'consentLimits' => %w[DRUG_ABUSE ALCOHOLISM HIV SICKLE_CELL],
            'consentAddressChange' => true,
            'claimant' => { 'claimantId' => '1013093331V548481',
                            'address' => { 'addressLine1' => '123 Main St', 'addressLine2' => 'Apt 3',
                                           'city' => 'Boston', 'stateCode' => 'MA', 'countryCode' => 'US',
                                           'zipCode' => '02110', 'zipCodeSuffix' => '1000' },
                            'phone' => { 'countryCode' => '1', 'areaCode' => '555', 'phoneNumber' => '5559876' },
                            'relationship' => 'Spouse' } } } }
    end

    it 'starts the POA auto establishment service' do
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler)
        .to receive(:poa_auto_establishment_gatherer)
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler)
        .to receive(:poa_auto_establishment_mapper)

      VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/valid_accepted_dependent') do
        subject.call
      end
    end

    context 'determines the type' do
      let(:organization) { create(:organization, poa: 'B12') }
      let(:representative) { create(:representative, representative_id: '123456783', poa_codes: ['A1Y']) }

      it 'correctly for an organization' do
        subject.instance_variable_set(:@poa_code, organization.poa)

        res = subject.send(:determine_type)

        expect(res).to eq(organization_type)
      end

      it 'correctly for an individual' do
        subject.instance_variable_set(:@poa_code, representative.poa_codes.first)

        res = subject.send(:determine_type)

        expect(res).to eq(individual_type)
      end
    end

    it 'returns the correct data to the caller' do
      allow_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper
      ).to receive(:representative_type).and_return('ATTORNEY')

      VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/valid_accepted_dependent') do
        res = subject.call

        expect(res).to eq([returned_data, individual_type])
      end
    end
  end
end
