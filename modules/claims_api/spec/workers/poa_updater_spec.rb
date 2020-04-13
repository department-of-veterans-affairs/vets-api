# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'lighthouse_bgs'

Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::PoaUpdater, type: :job do
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

  it "updates the form's status" do
    poa = create_poa
    create_mock_lighthouse_service
    subject.new.perform(poa.id)
    poa.reload
    expect(poa.status).to eq('updated')
  end

  private

  def create_poa
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  def create_mock_lighthouse_service
    vet_record_stub = LighthouseBGS::Services.new(external_uid: 'uid', external_key: 'key').vet_record
    allow(vet_record_stub).to receive(:update_birls_record).and_return(return_code: 'BMOD0001')
    service_double = instance_double('LighthouseBGS::Services')
    expect(service_double).to receive(:vet_record).and_return(vet_record_stub)
    expect(LighthouseBGS::Services).to receive(:new).and_return(service_double)
  end
end
