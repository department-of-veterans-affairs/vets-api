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

  let(:poa) do
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  it "updates the form's status" do
    vet_record_stub = LighthouseBGS::Services.new.vet_record
    allow(vet_record_stub).to receive(:update_birls_record).and_return('return_code' => 'BMOD0001')
    service_double = instance_double('LighthouseBGS::Services')
    expect(service_double).to receive(:vet_record).and_return(vet_record_stub)
    expect(LighthouseBGS::Services).to receive(:new).and_return(service_double)
    subject.new.perform(poa.id)
    poa.reload
    expect(poa.status).to eq('updated')
  end
end
