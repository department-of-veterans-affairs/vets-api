# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::VBMSUpdater, type: :job do
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

  it 'updates a the BIRLS record for a qualifying POA submittal' do
    poa = create_poa
    create_mock_lighthouse_service
    subject.new.perform(poa.id, user.participant_id)
  end

  private

  def create_poa
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  def create_mock_lighthouse_service
    corporate_update_stub = BGS::Services.new(external_uid: 'uid', external_key: 'key').corporate_update
    allow(corporate_update_stub).to receive(:update_poa_access)
    service_double = instance_double('BGS::Services')
    expect(service_double).to receive(:corporate_update).and_return(corporate_update_stub)
    expect(BGS::Services).to receive(:new).and_return(service_double)
  end
end
