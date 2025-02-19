# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/client'
require 'gi/lcpe/response'

RSpec.describe 'V1::GI::LCPE::Exams', type: :request do
  include SchemaMatchers

  let(:v_fresh) { '3' }
  let(:v_stale) { '2' }
  let(:enriched_id) { "1@#{v_client}" }

  describe 'GET v1/gi/lcpe/exams' do
    let(:lcpe_type) { 'exams' }
    let(:lcpe_cache) { LCPERedis.new(lcpe_type:) }
    let(:service) { GI::LCPE::Client.new(v_client:, lcpe_type:) }

    context 'when filter params present' do
      it 'bypasses versioning and returns lacs with 200 response' do
        VCR.use_cassette('gi/lcpe/get_exams_versioning_disabled') do
          get v1_gi_lcpe_exams_url, params: { state: 'MT' }
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('gi/lcpe/exams')
          expect(response.headers['Etag']).not_to match(/^[0-9]*$/)
        end
      end
    end

    context 'when versioning enabled' do
      context 'when client nil and cache nil' do
        it 'returns 200 response with fresh version' do
          VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
            get v1_gi_lcpe_exams_url
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('gi/lcpe/exams_with_version')
            expect(response.headers['Etag']).to eq(v_fresh)
          end
        end
      end

      context 'when client stale and cache stale' do
        let(:v_client) { v_stale }

        before do
          # generate stale cache
          VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
            service.get_exams_v1({})
            body = lcpe_cache.cached_response.body.merge(version: v_stale)
            lcpe_cache.cache(lcpe_type, GI::LCPE::Response.new(status: 200, body:))
          end
        end

        it 'returns 200 response with fresh version' do
          VCR.use_cassette('gi/lcpe/get_exams_cache_stale') do
            get v1_gi_lcpe_exams_url, headers: { 'If-None-Match' => v_client }
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('gi/lcpe/exams_with_version')
            expect(response.headers['Etag']).to eq(v_fresh)
          end
        end
      end

      context 'when client stale and cache fresh' do
        let(:v_client) { v_stale }

        before do
          # generate fresh cache
          VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
            service.get_exams_v1({})
          end
        end

        it 'returns 200 response with fresh version' do
          VCR.use_cassette('gi/lcpe/get_exams_cache_fresh') do
            get v1_gi_lcpe_exams_url, headers: { 'If-None-Match' => v_client }
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('gi/lcpe/exams_with_version')
            expect(response.headers['Etag']).to eq(v_fresh)
          end
        end
      end

      context 'when client fresh and cache fresh' do
        let(:v_client) { v_fresh }

        before do
         # generate fresh cache
          VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
            service.get_exams_v1({})
          end
        end

        it 'returns 304 response with fresh version' do
          VCR.use_cassette('gi/lcpe/get_exams_cache_fresh') do
            get v1_gi_lcpe_exams_url, headers: { 'If-None-Match' => v_client }
            expect(response).to have_http_status(:not_modified)
            expect(response.headers['Etag']).to eq(v_client)
          end
        end
      end
    end
  end

  describe 'GET v1/gi/lcpe/exams/:id' do
    context 'when client requests details with stale cache' do
      let(:v_client) { v_stale }

      it 'returns 409 conflict' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_stale') do
          get "#{v1_gi_lcpe_exams_url}/#{enriched_id}"
          expect(response).to have_http_status(:conflict)
        end
      end
    end

    context 'when client requests details with fresh cache' do
      let(:v_client) { v_fresh }

      it 'returns 200 response with lac details' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_fresh') do
          VCR.use_cassette('gi/lcpe/get_exam_details') do
            get "#{v1_gi_lcpe_exams_url}/#{enriched_id}"
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('gi/lcpe/exam')
          end
        end
      end
    end
  end
end
