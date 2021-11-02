# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::BigQuery do
  let!(:bigquery) { instance_double('Google::Cloud::Bigquery') }

  before do
    allow(Google::Cloud::Bigquery).to receive(:configure).and_return(true)
    allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
  end

  describe '#initialize' do
    it 'sets the bigquery instance variable' do
      expect(TestUserDashboard::BigQuery.new.bigquery).to eq(bigquery)
    end
  end
end
