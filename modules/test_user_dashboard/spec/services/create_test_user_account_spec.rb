# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::CreateTestUserAccount do
  subject { described_class.new }

  let(:file_path) { Rails.root.join('modules', 'test_user_dashboard', 'spec', 'support', 'spec_users.csv') }
  let(:users) { CSV.read(file_path, headers: true) }

  describe '#call' do
    it 'sets the account_id and services' do
      user = users[0]
      TestUserDashboard::CreateTestUserAccount.new(user).call
      tud_account = TestUserDashboard::TudAccount.find_by(email: user.to_hash['email'])

      expect(tud_account.account_uuid).not_to be_nil
      expect(tud_account.services).to eq %w[facilities hca edu_benefits form-save-in-progress
                                            form-prefill user-profile appeals-status
                                            identity-proofed vet360 claim_increase]
      expect(tud_account).to be_a(TestUserDashboard::TudAccount)
    end
  end
end
