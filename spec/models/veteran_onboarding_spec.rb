# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranOnboarding, type: :model do
  let(:user) { build(:user, :loa3) }
  let(:user_account) { user.user_account }

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
    Flipper.enable(:veteran_onboarding_beta_flow, user) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    expect { VeteranOnboarding.for_user(user) }.to change(VeteranOnboarding, :count).by(1)
  end

  describe '#show_onboarding_flow_on_login' do
    it 'returns the value of display_onboarding_flow' do
      subject = described_class.for_user(user)
      Flipper.enable(:veteran_onboarding_beta_flow, user) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      expect(subject.show_onboarding_flow_on_login).to be_truthy
    end

    it 'returns false and updates the database when verification is past the threshold' do
      Flipper.enable(:veteran_onboarding_show_to_newly_onboarded, user) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      Settings.veteran_onboarding = OpenStruct.new(onboarding_threshold_days: 10)
      verified_at_date = Time.zone.today - 11
      allow_any_instance_of(UserVerification).to receive(:verified_at).and_return(verified_at_date)

      veteran_onboarding = VeteranOnboarding.for_user(user)
      expect(veteran_onboarding.show_onboarding_flow_on_login).to be(false)

      veteran_onboarding.reload
      expect(veteran_onboarding.display_onboarding_flow).to be(false)
    end

    [
      { days_ago: 10, expected: true },
      { days_ago: 0, expected: true },
      { days_ago: 11, expected: false }
    ].each do |scenario|
      Settings.veteran_onboarding = OpenStruct.new(onboarding_threshold_days: 10)
      it "returns #{scenario[:expected]} when verified #{scenario[:days_ago]} days ago" do
        verified_at_date = Time.zone.today - scenario[:days_ago]
        allow_any_instance_of(UserVerification).to receive(:verified_at).and_return(verified_at_date)
        Flipper.enable(:veteran_onboarding_show_to_newly_onboarded, user) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        expect(user.onboarding&.show_onboarding_flow_on_login).to eq(scenario[:expected])
      end
    end
  end
end
