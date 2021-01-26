# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::CreateTestUserAccount do
  subject { described_class.new }

  file_path = Rails.root.join('modules', 'test_user_dashboard', 'spec', 'support', 'spec_users.csv')
  spec_users = CSV.read(file_path, headers: true)

  describe '#initialize' do
    it 'has a test_user_account attribute' do
      expect(subject.respond_to?(:test_user_account)).to eq(true)
    end

    it 'its test_user_account is a TudAccount' do
      expect(subject.test_user_account).to be_a(TestUserDashboard::TudAccount)
    end
  end

  describe '#call' do
    it 'saves a new test user account' do
      expect { ::TestUserDashboard::CreateTestUserAccount.new(spec_users[0]).call }
        .to change(TestUserDashboard::TudAccount, :count).by(1)
    end
  end
end
