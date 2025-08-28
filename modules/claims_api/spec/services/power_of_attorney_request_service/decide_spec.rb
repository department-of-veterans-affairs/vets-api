# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::Decide do
  subject { ClaimsApi::PowerOfAttorneyRequestService::Decide.new }

  let(:veteran_icn) { '1012861229V078999' }
  let(:claimant_icn) { '1013093331V548481' }

  let(:veteran) do
    OpenStruct.new(
      icn: veteran_icn,
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
  let(:lighthouse_id) { '111111' }

  describe '#validate_decide_representative_params!' do
    let(:decision) { 'ACCEPTED' }
    let(:representative_id) { '456' }
    let(:poa_code) { '123' }

    describe 'validating the params' do
      it 'raises ResourceNotFound error with descriptive message' do
        expect do
          subject.validate_decide_representative_params!(poa_code, representative_id)
        end.to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound)
      end
    end

    context 'registration number and POA code combination belong to a representative' do
      let!(:rep) { create(:representative, representative_id: '456', poa_codes: ['123']) }

      it 'does not raise an error' do
        expect do
          subject.validate_decide_representative_params!(poa_code, representative_id)
        end.not_to raise_error
      end
    end
  end

  describe '#get_poa_request' do
    let(:ptcpnt_id) { '600061742' }

    it 'returns the lighthouse ID appended onto the record object' do
      VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_by_ptcpnt_id') do
        response = subject.get_poa_request(ptcpnt_id:, lighthouse_id:)

        expect(response['id']).to eq(lighthouse_id)
      end
    end
  end

  describe '#build_veteran_and_dependent_data' do
    let(:metadata_without_dependent) do
      { 'veteran' => { 'vnp_mail_id' => '158492', 'vnp_email_id' => '158491', 'vnp_phone_id' => '112642' } }
    end
    let(:metadata_with_dependent) do
      {
        'veteran' => { 'vnp_mail_id' => '158481', 'vnp_email_id' => '158482', 'vnp_phone_id' => '112638' },
        'claimant' => { 'vnp_mail_id' => '158483', 'vnp_email_id' => '158484', 'vnp_phone_id' => '112639' }
      }
    end
    let(:build_target_veteran) { double('build_target_veteran') }

    context 'without a dependent' do
      let(:request) do
        create(:claims_api_power_of_attorney_request, veteran_icn:,
                                                      poa_code: '067', metadata: metadata_without_dependent)
      end

      before do
        allow(
          build_target_veteran
        ).to receive(:call).with(
          { loa: { current: 3, highest: 3 }, veteran_id: veteran.icn }
        ).and_return(veteran)
      end

      it 'returns the veteran data' do
        res = subject.build_veteran_and_dependent_data(request, build_target_veteran)

        expect(res).to eq([veteran, nil])
      end
    end

    context 'with the dependent data' do
      let(:request) do
        create(:claims_api_power_of_attorney_request, veteran_icn:,
                                                      claimant_icn:, poa_code: '067', metadata: metadata_with_dependent)
      end

      before do
        allow(
          build_target_veteran
        ).to receive(:call).with(
          { loa: { current: 3, highest: 3 }, veteran_id: veteran.icn }
        ).and_return(veteran)

        allow(
          build_target_veteran
        ).to receive(:call).with(
          { loa: { current: 3, highest: 3 }, veteran_id: claimant.icn }
        ).and_return(claimant)
      end

      it 'returns the veteran data' do
        res = subject.build_veteran_and_dependent_data(request, build_target_veteran)

        expect(res).to eq([veteran, claimant])
      end
    end
  end

  describe '#handle_poa_response' do
    before do
      allow_any_instance_of(described_class).to receive(:get_poa_request).and_return({})
    end

    it 'returns the claimant first and last name appended onto the record object' do
      response = subject.handle_poa_response(lighthouse_id, veteran, claimant)

      expect(response['claimantFirstName']).to eq(claimant.first_name)
      expect(response['claimantLastName']).to eq(claimant.last_name)
    end
  end
end
