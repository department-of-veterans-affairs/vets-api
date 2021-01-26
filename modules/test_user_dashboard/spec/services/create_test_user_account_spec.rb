# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::CreateTestUserAccount do
  subject { described_class.new }

  let(:file_path) { Rails.root.join('modules', 'test_user_dashboard', 'spec', 'support', 'spec_users.csv') }
  let(:users) { CSV.read(file_path, headers: true) }

  describe '#initialize' do
    it { expect(subject.test_user_account).to be_a(TestUserDashboard::TudAccount) }
  end

  describe '#call' do
    it 'saves a new test user account' do
      expect { ::TestUserDashboard::CreateTestUserAccount.new(users[0]).call }
        .to change(TestUserDashboard::TudAccount, :count).by(1)
    end
  end
end
