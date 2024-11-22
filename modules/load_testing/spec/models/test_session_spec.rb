require 'rails_helper'

RSpec.describe LoadTesting::TestSession, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:concurrent_users) }
  end

  describe 'associations' do
    it { should have_many(:test_tokens).dependent(:destroy) }
  end

  describe '.active' do
    let!(:pending_session) { create(:load_testing_test_session, status: 'pending') }
    let!(:running_session) { create(:load_testing_test_session, status: 'running') }
    let!(:completed_session) { create(:load_testing_test_session, status: 'completed') }

    it 'returns only pending and running sessions' do
      active_sessions = described_class.active
      expect(active_sessions).to include(pending_session, running_session)
      expect(active_sessions).not_to include(completed_session)
    end
  end
end 