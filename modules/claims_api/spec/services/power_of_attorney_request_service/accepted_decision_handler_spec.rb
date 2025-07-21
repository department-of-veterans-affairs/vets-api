# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler do
  subject { described_class.new(proc_id:, poa_code:, representative_id:, metadata:, veteran:, claimant:) }

  let(:clazz) { described_class }
  let(:representative_id) { '12399998' }

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
  let(:proc_id) { '3864182' }
  let(:poa_code) { '083' }

  context 'for a valid decide request' do
    let(:proc_id) { '3864182' }
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
        'veteran' => { 'vnp_mail_id' => '157252', 'vnp_email_id' => '157251', 'vnp_phone_id' => '111641' },
        'claimant' => { 'vnp_mail_id' => '157253', 'vnp_email_id' => '157254', 'vnp_phone_id' => '111642' }
      }
    end

    it 'starts the POA auto establishment service' do
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler)
        .to receive(:poa_auto_establishment_mapper)

      VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/valid_accepted_dependent') do
        subject.call
      end
    end
  end
end
