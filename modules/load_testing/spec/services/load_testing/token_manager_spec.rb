require 'rails_helper'

RSpec.describe LoadTesting::TokenManager do
  let(:test_session) { create(:load_testing_test_session) }
  let(:token_manager) { described_class.new(test_session) }

  describe '#generate_tokens' do
    it 'creates the specified number of tokens' do
      expect {
        token_manager.generate_tokens(5)
      }.to change(LoadTesting::TestToken, :count).by(5)
    end

    it 'associates tokens with the test session' do
      token_manager.generate_tokens(3)
      expect(test_session.test_tokens.count).to eq(3)
    end
  end

  describe '#refresh_tokens' do
    let!(:expired_token) do
      create(:load_testing_test_token,
             test_session: test_session,
             expires_at: 4.minutes.from_now)
    end

    it 'refreshes tokens that are about to expire' do
      token_manager.refresh_tokens
      expired_token.reload
      expect(expired_token.expires_at).to be > 25.minutes.from_now
    end
  end
end 