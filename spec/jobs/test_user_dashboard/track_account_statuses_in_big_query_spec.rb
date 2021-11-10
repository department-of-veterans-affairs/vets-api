# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestUserDashboard::TrackAccountStatusesInBigQuery do
  describe '#perform' do
    let!(:accounts) { [create(:tud_account)] }
    let!(:client) { instance_double('TestUserDashboard::BigQuery', insert_into: true) }

    before do
      allow(TestUserDashboard::BigQuery).to receive(:new).and_return(client)
      allow(TestUserDashboard::TudAccount).to receive(:all).and_return(accounts)
    end

    it 'posts statuses to BigQuery' do
      expect(client).to receive(:insert_into)
      described_class.new.perform
    end
  end
end
