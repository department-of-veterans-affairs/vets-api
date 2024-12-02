require 'rails_helper'

RSpec.describe LoadTesting::TestSession, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:concurrent_users) }
    it { should have_many(:test_tokens).dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 'pending', running: 'running', completed: 'completed', failed: 'failed') }
  end

  describe '.active' do
    it 'returns sessions that are pending or running' do
      pending_session = create(:load_testing_test_session, status: 'pending')
      running_session = create(:load_testing_test_session, status: 'running')
      completed_session = create(:load_testing_test_session, status: 'completed')

      expect(described_class.active).to include(pending_session, running_session)
      expect(described_class.active).not_to include(completed_session)
    end
  end
end 