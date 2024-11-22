require 'rails_helper'

RSpec.describe LoadTesting::TestToken, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:access_token) }
    it { should validate_presence_of(:refresh_token) }
    it { should validate_presence_of(:expires_at) }
  end

  describe 'associations' do
    it { should belong_to(:test_session) }
  end

  describe '#needs_refresh?' do
    let(:token) { create(:load_testing_test_token) }

    context 'when token expires soon' do
      before { token.update(expires_at: 4.minutes.from_now) }

      it 'returns true' do
        expect(token.needs_refresh?).to be true
      end
    end

    context 'when token is not close to expiring' do
      before { token.update(expires_at: 10.minutes.from_now) }

      it 'returns false' do
        expect(token.needs_refresh?).to be false
      end
    end
  end
end 