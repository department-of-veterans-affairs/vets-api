# frozen_string_literal: true

require 'rails_helper'
require 'bgs/service'
require 'mpi/service'
require 'evss/service'

RSpec.describe 'Claims Status Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/claims/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  describe '#healthcheck' do
    %w[v1 v2].each do |version|
      context version do
        it 'returns a successful health check' do
          get "/services/claims/#{version}/healthcheck"

          parsed_response = JSON.parse(response.body)
          expect(response).to have_http_status(:ok)
          expect(parsed_response['default']['message']).to eq('Application is running')
          expect(parsed_response['default']['success']).to eq(true)
          expect(parsed_response['default']['time']).not_to be_nil
        end
      end
    end
  end

  describe '#upstream_healthcheck' do
    before do
      time = Time.utc(2020, 9, 21, 0, 0, 0)
      Timecop.freeze(time)
    end

    after { Timecop.return }

    %w[v1].each do |version|
      context version do
        it 'returns correct response and status when healthy' do
          allow(EVSS::Service).to receive(:service_is_up?).and_return(true)
          allow(MPI::Service).to receive(:service_is_up?).and_return(true)
          allow_any_instance_of(BGS::Services).to receive(:vet_record).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(BGS::Services).to receive(:corporate_update).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(BGS::Services).to receive(:intent_to_file).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(BGS::Services).to receive(:claimant).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(BGS::Services).to receive(:contention).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(Struct.new(:status).new(200))
          get "/services/claims/#{version}/upstream_healthcheck"
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'when a v1 upstream service is not healthy' do
    it 'returns the correct status' do
      allow(EVSS::Service).to receive(:service_is_up?).and_return(false)
      allow(MPI::Service).to receive(:service_is_up?).and_return(false)
      allow_any_instance_of(BGS::Services).to receive(:vet_record).and_return(Struct.new(:status).new(500))
      allow_any_instance_of(BGS::Services).to receive(:corporate_update).and_return(Struct.new(:status).new(500))
      allow_any_instance_of(BGS::Services).to receive(:intent_to_file).and_return(Struct.new(:status).new(500))
      allow_any_instance_of(BGS::Services).to receive(:claimant).and_return(Struct.new(:status).new(500))
      allow_any_instance_of(BGS::Services).to receive(:contention).and_return(Struct.new(:status).new(500))
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(Struct.new(:status).new(500))

      get '/services/claims/v1/upstream_healthcheck'

      res = JSON.parse(response.body)
      expect(res['evss']['message']).to eq('EVSS is unavailable')
      expect(res['mpi']['message']).to eq('MPI is unavailable')
      expect(res['bgs-vet_record']['message']).to eq('BGS vet_record is unavailable')
      expect(res['bgs-corporate_update']['message']).to eq('BGS corporate_update is unavailable')
      expect(res['bgs-intent_to_file']['message']).to eq('BGS intent_to_file is unavailable')
      expect(res['bgs-claimant']['message']).to eq('BGS claimant is unavailable')
      expect(res['bgs-contention']['message']).to eq('BGS contention is unavailable')
      expect(res['vbms']['message']).to eq('VBMS is unavailable')
    end
  end

  describe 'when a v2 upstream service is not healthy' do
    it 'returns the correct status' do
      allow(MPI::Service).to receive(:service_is_up?).and_return(false)
      allow_any_instance_of(BGS::Services).to receive(:ebenefits_benefit_claims_status)
        .and_return(Struct.new(:status).new(500))
      allow_any_instance_of(BGS::Services).to receive(:intent_to_file).and_return(Struct.new(:status).new(500))
      allow_any_instance_of(BGS::Services).to receive(:intent_to_file).and_return(Struct.new(:status).new(500))
      allow_any_instance_of(BGS::Services).to receive(:tracked_items).and_return(Struct.new(:status).new(500))

      get '/services/claims/v2/upstream_healthcheck'

      res = JSON.parse(response.body)
      expect(res['mpi']['message']).to eq('MPI is unavailable')
      expect(res['bgs-ebenefits_benefit_claims_status']['message'])
        .to eq('BGS ebenefits_benefit_claims_status is unavailable')
      expect(res['bgs-intent_to_file']['message']).to eq('BGS intent_to_file is unavailable')
      expect(res['bgs-tracked_items']['message']).to eq('BGS tracked_items is unavailable')
    end
  end
end
