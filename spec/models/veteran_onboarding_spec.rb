# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranOnboarding, type: :model do
  let(:user_verification) { create(:user_verification) }
  let(:user_account) { user_verification.user_account }
  let(:user) { build(:user, :loa3, idme_uuid: user_verification.idme_uuid) }

  describe 'validations' do
    it 'validates presence of user_account_uuid' do
      subject = described_class.new(user_account: nil)
      expect(subject).not_to be_valid
      expect(subject.errors.details[:user_account]).to include(error: :blank)
    end

    it 'validates uniqueness of user_account_uuid' do
      described_class.create!(user_account:)
      subject = described_class.new(user_account:)
      expect(subject).not_to be_valid
      expect(subject.errors.details[:user_account]).to include(error: :taken, value: user_account)
    end
  end

  it 'creates a VeteranOnboarding object if toggle is enabled' do
    Flipper.enable(:veteran_onboarding_beta_flow, user)
    expect { VeteranOnboarding.for_user(user) }.to change(VeteranOnboarding, :count).by(1)
  end

  describe '#show_onboarding_flow_on_login' do
    it 'returns the value of display_onboarding_flow' do
      subject = described_class.for_user(user)
      Flipper.enable(:veteran_onboarding_beta_flow, user)
      expect(subject.show_onboarding_flow_on_login).to be_truthy
    end

    # default logic to show onboarding is 180 days, can be overridden by setting value in
    # Settings.veteran_onboarding.onboarding_threshold_days
    [
      { days_ago: 180, expected: true },
      { days_ago: 0, expected: true },
      { days_ago: 181, expected: false }
    ].each do |scenario|
      it "returns #{scenario[:expected]} when verified #{scenario[:days_ago]} days ago" do
        verified_at_date = Time.zone.today - scenario[:days_ago]
        allow(user.user_verification).to receive(:verified_at).and_return(verified_at_date)
        Flipper.enable(:veteran_onboarding_show_to_newly_onboarded, user)
        expect(user.onboarding&.show_onboarding_flow_on_login).to eq(scenario[:expected])
      end
    end
  end
end
