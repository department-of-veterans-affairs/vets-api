# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Veteran::VSOReloader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  describe 'importer' do
    it 'reloads data from pulldown' do
      VCR.use_cassette('veteran/ogc_poa_data') do
        Veteran::VSOReloader.new.perform
        expect(Veteran::Service::Representative.count).to eq 435
        expect(Veteran::Service::Organization.count).to eq 3
        expect(Veteran::Service::Representative.attorneys.count).to eq 241
        expect(Veteran::Service::Representative.veteran_service_officers.count).to eq 152
        expect(Veteran::Service::Representative.claim_agents.count).to eq 42
      end
    end

    it 'loads attorneys with the poa codes loaded' do
      VCR.use_cassette('veteran/ogc_attorney_data') do
        Veteran::VSOReloader.new.reload_attorneys
        expect(Veteran::Service::Representative.last.poa_codes).to include('9GB')
      end
    end

    it 'loads a claim agent with the poa code' do
      VCR.use_cassette('veteran/ogc_claim_agent_data') do
        Veteran::VSOReloader.new.reload_claim_agents
        expect(Veteran::Service::Representative.last.poa_codes).to include('FDN')
      end
    end

    it 'loads a vso rep with the poa code' do
      VCR.use_cassette('veteran/ogc_vso_rep_data') do
        Veteran::VSOReloader.new.reload_vso_reps
        expect(Veteran::Service::Representative.last.poa_codes).to include('091')
      end
    end

    context 'with a failed connection' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed,
                                                                               'some message')
      end

      it 'notifies slack' do
        expect_any_instance_of(SlackNotify::Client).to receive(:notify)
        Veteran::VSOReloader.new.perform
      end
    end

    context 'with an client error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Common::Client::Errors::ClientError)
      end

      it 'notifies slack' do
        expect_any_instance_of(SlackNotify::Client).to receive(:notify)
        subject.new.perform
      end
    end
  end
end
