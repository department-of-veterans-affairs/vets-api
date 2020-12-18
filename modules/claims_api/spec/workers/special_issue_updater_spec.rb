# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::SpecialIssueUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:special_issues) { %w[ALS PTSD/2] }
  let(:claim_unestablished) { create(:auto_established_claim) }
  let(:claim_established) { create(:auto_established_claim, :status_established) }

  it 'submits succesfully' do
    VCR.use_cassette('contention_web_service/add_special_issues_to_contention') do
      expect_any_instance_of(BGS::ContentionService).to receive(:manage_contentions)
      subject.new.perform(user, special_issues, auto_established_claim: claim_established)
    end
  end
end
