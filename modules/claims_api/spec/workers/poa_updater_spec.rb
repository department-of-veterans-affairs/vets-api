# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::PoaUpdater, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  subject { described_class }

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let!(:poa) do
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  it "updates the form's status" do
    binding.pry
    # subject.new.perform(poa.id, _)
  end
end
