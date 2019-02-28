# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::ClaimEstablisher, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  subject { described_class }

  let(:user) { FactoryBot.create(:user, :loa3, ssn: 796_104_437) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:claim) do
    claim = create(:auto_established_claim)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  it 'submits succesfully' do
    VCR.use_cassette('evss/disability_compensation_form/external_api/submit_form') do
      expect do
        subject.perform_async(claim.id)
      end.to change(subject.jobs, :size).by(1)
      subject.new.perform(claim.id)
    end
  end
end
