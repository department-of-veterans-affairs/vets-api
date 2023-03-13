# frozen_string_literal: true

require 'rails_helper'
require 'pagerduty/maintenance_client'

describe PagerDuty::MaintenanceClient do
  let(:subject) { described_class.new }

  before(:all) do
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
          body: body
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
          body: body
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

  context 'with options specified' do
    let(:body) { File.read('spec/support/pagerduty/maintenance_windows_simple.json') }

    it 'gets maintenance windows with services in query' do
      stub_request(:get, 'https://api.pagerduty.com/maintenance_windows')
        .with(query: hash_including('service_ids' => %w[ABCDEF]))
        .to_return(
          status: 200,
          headers: { 'Content-Type' => 'application/json; charset=utf-8' },
          body: body
        )
      windows = subject.get_all('service_ids' => %w[ABCDEF])
      expect(windows).to be_a(Array)
      expect(windows.first).to be_a(Hash)
      expect(windows.first.keys).to include(:pagerduty_id, :external_service, :start_time, :end_time, :description)
    end
  end
end
