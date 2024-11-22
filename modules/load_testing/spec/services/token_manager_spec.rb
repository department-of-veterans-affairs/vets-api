require 'rails_helper'

RSpec.describe LoadTesting::TokenManager do
  let(:test_session) { create(:load_testing_test_session) }
  let(:token_manager) { described_class.new(test_session) }

  describe '#generate_tokens' do
    it 'creates the specified number of tokens' do
      expect { token_manager.generate_tokens(3) }
        .to change { test_session.test_tokens.count }.by(3)
    end

    it 'creates valid tokens' do
      token_manager.generate_tokens(1)
      token = test_session.test_tokens.last

      expect(token.access_token).to be_present
      expect(token.refresh_token).to be_present
      expect(token.device_secret).to be_present
      expect(token.expires_at).to be > Time.current
    end
  end

  describe '#refresh_tokens' do
    let!(:expired_token) do
      create(:load_testing_test_token,
             test_session: test_session,
             expires_at: 4.minutes.from_now)
    end
    let!(:valid_token) do
      create(:load_testing_test_token,
             test_session: test_session,
             expires_at: 25.minutes.from_now)
    end

    it 'refreshes only tokens that need refresh' do
      old_expired_token = expired_token.refresh_token
      old_valid_token = valid_token.refresh_token

      token_manager.refresh_tokens

      expired_token.reload
      valid_token.reload

      expect(expired_token.refresh_token).not_to eq(old_expired_token)
      expect(valid_token.refresh_token).to eq(old_valid_token)
    end
  end
end 