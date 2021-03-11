# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::CreateTestUserAccount do
  subject { described_class.new }

  let(:file_path) { Rails.root.join('modules', 'test_user_dashboard', 'spec', 'support', 'spec_users.csv') }
  let(:users) { CSV.read(file_path, headers: true) }

  describe '#call' do
    it 'sets the account_id and services' do
      VCR.use_cassette('mpi/find_candidate/find_profile_with_attributes', VCR::MATCH_EVERYTHING) do
        tud_account = ::TestUserDashboard::CreateTestUserAccount.new(users[0]).call
        expect(tud_account.account_uuid).not_to be_nil
        expect(tud_account.services).to eq %w[facilities hca edu-benefits form-save-in-progress
                                              form-prefill]
        expect(tud_account).to be_a(TestUserDashboard::TudAccount)
      end
    end
  end
end
