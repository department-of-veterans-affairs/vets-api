# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe Veteran::VsoReloader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  describe 'importer' do
    it 'reloads data from pulldown' do
      VCR.use_cassette('veteran/ogc_poa_data') do
        Veteran::VsoReloader.new.perform
        expect(Veteran::Service::Representative.count).to eq 435
        expect(Veteran::Service::Organization.count).to eq 3
        expect(Veteran::Service::Representative.attorneys.count).to eq 241
        expect(Veteran::Service::Representative.veteran_service_officers.count).to eq 152
        expect(Veteran::Service::Representative.claim_agents.count).to eq 42
      end
    end

    it 'loads attorneys with the poa codes loaded' do
      VCR.use_cassette('veteran/ogc_attorney_data') do
        Veteran::VsoReloader.new.reload_attorneys
        expect(Veteran::Service::Representative.last.poa_codes).to include('9GB')
      end
    end

    it 'loads a claim agent  with the poa code' do
      VCR.use_cassette('veteran/ogc_claim_agent_data') do
        Veteran::VsoReloader.new.reload_claim_agents
        expect(Veteran::Service::Representative.last.poa_codes).to include('FDN')
      end
    end

    it 'loads a vso rep with the poa code' do
      VCR.use_cassette('veteran/ogc_vso_rep_data') do
        Veteran::VsoReloader.new.reload_vso_reps
        expect(Veteran::Service::Representative.last.poa_codes).to include('091')
      end
    end
  end
end
