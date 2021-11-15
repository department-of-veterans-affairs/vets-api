# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestUserDashboard::MirrorAccountsInBigQuery do
  describe '#perform' do
    let!(:client) do
      instance_double('TestUserDashboard::BigQuery',
                      delete_from: true,
                      insert_into: true)
    end

    before do
      allow(TestUserDashboard::BigQuery).to receive(:new).and_return(client)
    end

    it 'mirrors TUD accounts in BigQuery' do
      expect(client).to receive(:delete_from)
      expect(client).to receive(:insert_into)
      described_class.new.perform
    end
  end
end
