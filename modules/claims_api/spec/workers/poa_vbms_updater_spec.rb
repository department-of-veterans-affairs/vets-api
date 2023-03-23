# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::PoaVBMSUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  context 'when address change is present and allowed' do
    let(:allow_poa_c_add) { 'y' }
    let(:consent_address_change) { true }

    it 'updates a the BIRLS record for a qualifying POA submittal' do
      poa = create_poa
      create_mock_lighthouse_service
      subject.new.perform(poa.id)
    end
  end

  context 'when address change is present and not allowed' do
    let(:allow_poa_c_add) { 'n' }
    let(:consent_address_change) { false }

    it 'updates a the BIRLS record for a qualifying POA submittal' do
      poa = create_poa
      create_mock_lighthouse_service
      subject.new.perform(poa.id)
    end
  end

  context 'when address change is not present' do
    let(:allow_poa_c_add) { 'n' }
    let(:consent_address_change) { nil }

    it 'updates a the BIRLS record for a qualifying POA submittal' do
      poa = create_poa
      create_mock_lighthouse_service
      subject.new.perform(poa.id)
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
end
