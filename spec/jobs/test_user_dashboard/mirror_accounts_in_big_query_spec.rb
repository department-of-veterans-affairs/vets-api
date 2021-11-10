# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestUserDashboard::MirrorAccountsInBigQuery do
  describe '#perform' do
    let!(:client) do
      instance_double('TestUserDashboard::BigQuery',
                      drop: true,
                      create: true)
    end

    before do
      allow(TestUserDashboard::BigQuery).to receive(:new).and_return(client)
    end

    it 'mirrors TUD accounts in BigQuery' do
      expect(client).to receive(:drop)
      expect(client).to receive(:create)
      described_class.new.perform
    end
  end
end
