# frozen_string_literal: true

describe TestUserDashboard::CreateTestUserAccount do
  subject { described_class.new }

  describe '#initialize' do
    it 'has a test_user_account attribute' do
      expect(subject.respond_to?(:test_user_account)).to eq(true)
    end

    it 'its test_user_account is a TudAccount' do
      expect(subject.test_user_account).to be_a(TestUserDashboard::TudAccount)
    end
  end
end
