# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestUserDashboard::DailyMaintenance do
  describe '#perform' do
    let!(:accounts) { [create(:tud_account)] }

    before do
      # rubocop:disable RSpec/MessageChain
      allow(TestUserDashboard::TudAccount).to receive_message_chain(:where, :not).and_return(accounts)
      # rubocop:enable RSpec/MessageChain
      allow_any_instance_of(TestUserDashboard::TudAccount).to receive(:update).and_return(true)
      allow_any_instance_of(TestUserDashboard::AccountMetrics).to receive(:checkin).and_return(true)
    end

    it 'checks in TUD accounts' do
      # rubocop:disable RSpec/MessageChain
      expect(TestUserDashboard::TudAccount).to receive_message_chain(:where, :not)
      expect(TestUserDashboard::AccountMetrics).to receive_message_chain(:new, :checkin)
      # rubocop:enable RSpec/MessageChain
      described_class.new.perform
    end
  end
end
