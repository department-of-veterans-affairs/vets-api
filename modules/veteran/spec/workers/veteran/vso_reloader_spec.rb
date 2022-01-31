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
        expect(Veteran::Service::Representative.where(representative_id: '').count).to eq 0
      end
    end

    it 'loads attorneys with the poa codes loaded' do
      VCR.use_cassette('veteran/ogc_attorney_data') do
        Veteran::VSOReloader.new.reload_attorneys
        expect(Veteran::Service::Representative.last.poa_codes).to include('9GB')
        expect(Veteran::Service::Representative.where(representative_id: '').count).to eq 0
      end
    end

    it 'loads a claim agent with the poa code' do
      VCR.use_cassette('veteran/ogc_claim_agent_data') do
        Veteran::VSOReloader.new.reload_claim_agents
        expect(Veteran::Service::Representative.last.poa_codes).to include('FDN')
        expect(Veteran::Service::Representative.where(representative_id: '').count).to eq 0
      end
    end

    it 'loads a vso rep with the poa code' do
      VCR.use_cassette('veteran/ogc_vso_rep_data') do
        Veteran::VSOReloader.new.reload_vso_reps
        expect(Veteran::Service::Representative.last.poa_codes).to include('091')
        expect(Veteran::Service::Representative.where(representative_id: '').count).to eq 0
      end
    end

    context 'leaving test users alone' do
      before do
        Veteran::Service::Representative.create(
          representative_id: '98765',
          first_name: 'Tamara',
          last_name: 'Ellis',
          email: 'va.api.user+idme.001@gmail.com',
          poa_codes: %w[067 A1Q 095 074 083 1NY]
        )

        Veteran::Service::Representative.create(
          representative_id: '12345',
          first_name: 'John',
          last_name: 'Doe',
          email: 'va.api.user+idme.007@gmail.com',
          poa_codes: %w[072 A1H 095 074 083 1NY]
        )
      end

      it 'does not destroy test users' do
        VCR.use_cassette('veteran/ogc_poa_data') do
          Veteran::VSOReloader.new.perform
          expect(Veteran::Service::Representative.where(first_name: 'Tamara', last_name: 'Ellis').count).to eq 1
          expect(Veteran::Service::Representative.where(first_name: 'John', last_name: 'Doe').count).to eq 1
        end
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
