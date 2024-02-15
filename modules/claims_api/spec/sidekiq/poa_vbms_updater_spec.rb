# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::PoaVBMSUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  context 'when address change is present and allowed' do
    let(:allow_poa_c_add) { 'Y' }
    let(:consent_address_change) { true }

    it 'updates a the BIRLS record for a qualifying POA submittal' do
      poa = create_poa
      create_mock_lighthouse_service
      subject.new.perform(poa.id)
    end
  end

  context 'when address change is present and not allowed' do
    let(:allow_poa_c_add) { 'N' }
    let(:consent_address_change) { false }

    it 'updates a the BIRLS record for a qualifying POA submittal' do
      poa = create_poa
      create_mock_lighthouse_service
      subject.new.perform(poa.id)
    end
  end

  context 'when address change is not present' do
    let(:allow_poa_c_add) { 'N' }
    let(:consent_address_change) { nil }

    it 'updates a the BIRLS record for a qualifying POA submittal' do
      poa = create_poa
      create_mock_lighthouse_service
      subject.new.perform(poa.id)
    end
  end

  context 'when BGS fails the error is handled' do
    let(:allow_poa_c_add) { 'Y' }
    let(:consent_address_change) { true }

    it 'marks the form as errored' do
      poa = create_poa
      create_mock_lighthouse_service_bgs_failure # API-31645 real life example
      subject.new.perform(poa.id)

      poa.reload
      expect(poa.status).to eq('errored')
      expect(poa.vbms_error_message).to eq('updatePoaAccess: No POA found on system of record')
    end
  end

  context 'when an errored job has exhausted its retries' do
    let(:allow_poa_c_add) { 'Y' }
    let(:consent_address_change) { true }

    it 'logs to the ClaimsApi Logger' do
      poa = create_poa
      error_msg = 'An error occurred for the POA VBMS Updater Job'
      msg = { 'args' => [poa.id],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: poa.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end

  private

  def create_poa
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    if consent_address_change.present?
      poa.form_data = poa.form_data.merge('consentAddressChange' => consent_address_change)
    end
    poa.save
    poa
  end

  def create_mock_lighthouse_service
    corporate_update_stub = BGS::Services.new(external_uid: 'uid', external_key: 'key').corporate_update
    expect(corporate_update_stub).to receive(:update_poa_access).with(
      participant_id: user.participant_id,
      poa_code: '074',
      allow_poa_access: 'y',
      allow_poa_c_add:
    ).and_return({ return_code: 'GUIE50000' })
    service_double = instance_double('BGS::Services')
    expect(service_double).to receive(:corporate_update).and_return(corporate_update_stub)
    expect(BGS::Services).to receive(:new).and_return(service_double)
  end

  def create_mock_lighthouse_service_bgs_failure
    allow_any_instance_of(BGS::Services).to receive(:corporate_update) do |_instance|
      corporate_update_stub = instance_double('BGS::CorporateUpdate')
      allow(corporate_update_stub).to receive(:update_poa_access)
        .with(
          participant_id: user.participant_id,
          poa_code: '074',
          allow_poa_access: 'y',
          allow_poa_c_add:
        ).and_return({ return_code: 'GUIE50000' })
      corporate_update_stub
    end

    allow(BGS::Services).to receive(:new) do
      services_double = instance_double('BGS::Services')
      allow(services_double).to receive(:corporate_update)
        .and_raise(BGS::ShareError.new('updatePoaAccess: No POA found on system of record'))
      services_double
    end
  end
end
