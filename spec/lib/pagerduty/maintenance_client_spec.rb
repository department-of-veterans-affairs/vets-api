# frozen_string_literal: true

require 'rails_helper'
require 'pagerduty/maintenance_client'

describe PagerDuty::MaintenanceClient do
  let(:subject) { described_class.new }

  before(:all) do
    VCR.eject_cassette if VCR.current_cassette
    VCR.turn_off!
  end

  after(:all) do
    VCR.turn_on!
  end

  before do
    allow(Settings.maintenance).to receive(:services).and_return({ evss: 'ABCDEF', mhv: 'BCDEFG' })
  end

  context 'with single page of results' do
    let(:body) { File.read('spec/support/pagerduty/maintenance_windows_simple.json') }

    it 'gets open maintenance windows' do
      stub_request(:get, 'https://api.pagerduty.com/maintenance_windows')
        .with(query: hash_including('service_ids' => %w[ABCDEF BCDEFG]))
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json; charset=utf-8' },
          body:
        )
      windows = subject.get_all
      expect(windows).to be_a(Array)
      expect(windows.first).to be_a(Hash)
      expect(windows.first.keys).to include(:pagerduty_id, :external_service, :start_time, :end_time, :description)
    end

    it 'normalizes description to empty string' do
      stub_request(:get, 'https://api.pagerduty.com/maintenance_windows')
        .with(query: hash_including('service_ids' => %w[ABCDEF BCDEFG]))
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json; charset=utf-8' },
          body:
        )
      windows = subject.get_all
      expect(windows.first[:description]).to eq('')
      expect(windows.last[:description]).to eq('Multi-service Window')
    end
  end

  context 'with multiple pages of results' do
    let(:body1) { File.read('spec/support/pagerduty/maintenance_windows_page_1.json') }
    let(:body2) { File.read('spec/support/pagerduty/maintenance_windows_page_2.json') }

    it 'gets open maintenance windows' do
      stub_request(:get, 'https://api.pagerduty.com/maintenance_windows')
        .with(query: hash_including('service_ids' => %w[ABCDEF BCDEFG], 'offset' => '0'))
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json; charset=utf-8' },
          body: body1
        )
      stub_request(:get, 'https://api.pagerduty.com/maintenance_windows')
        .with(query: hash_including('service_ids' => %w[ABCDEF BCDEFG], 'offset' => '25'))
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json; charset=utf-8' },
          body: body2
        )
      windows = subject.get_all
      expect(windows.size).to eq(26)
    end
  end

  context 'with no configured services' do
    before { allow(Settings.maintenance).to receive(:services).and_return(nil) }

    it 'returns empty results' do
      windows = subject.get_all
      expect(windows).to be_empty
    end
  end

  context 'with bad requests' do
    before { allow(Settings.maintenance).to receive(:services).and_return({ evss: 'XBADXX' }) }

    it 'returns empty results and error with bad service IDs' do
      stub_request(:get, 'https://api.pagerduty.com/maintenance_windows')
        .with(query: hash_including('service_ids' => %w[XBADXX], 'offset' => '0'))
        .to_return(
          status: 400
        )

      expect(Rails.logger).to receive(:error)
        .with('Invalid arguments sent to PagerDuty. One of the following Service IDs is bad: ["XBADXX"]')

      windows = subject.get_all
      expect(windows).to be_empty
    end

    it 'returns empty results and custom error message on 429 error' do
      stub_request(:get, 'https://api.pagerduty.com/maintenance_windows')
        .with(query: hash_including('service_ids' => %w[XBADXX], 'offset' => '0'))
        .to_return(
          status: 429
        )

      # rubocop:disable Layout/LineLength
      error_message = 'Querying PagerDuty for maintenance windows failed with the error: BackendServiceException: {:status=>429, :detail=>nil, :code=>"PAGERDUTY_429", :source=>nil}'
      # rubocop:enable Layout/LineLength
      expect(Rails.logger).to receive(:error).with(error_message)

      windows = subject.get_all
      expect(windows).to be_empty
    end
  end

  context 'with options specified' do
    let(:body) { File.read('spec/support/pagerduty/maintenance_windows_simple.json') }

    it 'gets maintenance windows with services in query' do
      stub_request(:get, 'https://api.pagerduty.com/maintenance_windows')
        .with(query: hash_including('service_ids' => %w[ABCDEF]))
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json; charset=utf-8' },
          body:
        )
      windows = subject.get_all('service_ids' => %w[ABCDEF])
      expect(windows).to be_a(Array)
      expect(windows.first).to be_a(Hash)
      expect(windows.first.keys).to include(:pagerduty_id, :external_service, :start_time, :end_time, :description)
    end
  end
end
