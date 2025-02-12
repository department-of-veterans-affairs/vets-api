# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/client'

describe GI::LCPE::Client do
  let(:v_client) { nil }
  let(:lcpe_type) { nil }
  let(:lcpe_cache) { LCPERedis.new(lcpe_type:) }
  let(:v_fresh) { 3 }
  let(:v_stale) { v_fresh - 1 }

  def service
    GI::LCPE::Client.new(version_id: v_client.to_s, lcpe_type:)
  end

  describe '#get_licenses_and_certs_v1' do
    context 'when versioning disabled' do
      it 'gets list of licenses and certifications' do
        VCR.use_cassette('gi/lcpe/get_lacs_versioning_disabled') do
          response = service.get_licenses_and_certs_v1({ state: 'MT' })
          lacs = response.body[:lacs]
          expect(lacs.class).to be(Array)
          expect(lacs.first.keys).to eq(%i[enriched_id lac_nm edu_lac_type_nm state])
        end
      end
    end

    context 'when versioning enabled' do
      let(:lcpe_type) { 'lacs' }

      context 'when client nil and cache nil' do
        it 'gets list of licenses and certifications and includes fresh version' do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_nil') do
            response = service.get_licenses_and_certs_v1({})
            expect(response.version).not_to be_nil
            lacs = response.body[:lacs]
            expect(lacs.class).to be(Array)
            expect(lacs.first.keys).to eq(%i[enriched_id lac_nm edu_lac_type_nm state])
          end
        end
      end

      context 'when client stale and cache stale' do
        let(:v_client) { v_stale }

        let!(:cached_response) do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_nil') do
            response = service.get_licenses_and_certs_v1({})
            response.version = v_client
            lcpe_cache.cache(lcpe_type, response)
            LCPERedis.find(lcpe_type).response
          end
        end

        it 'gets list of licenses and certifications and includes fresh version' do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_stale') do
            response = service.get_licenses_and_certs_v1({})
            expect(response.version).to be > cached_response.version
            lacs = response.body[:lacs]
            expect(lacs.class).to be(Array)
            expect(lacs.first.keys).to eq(%i[enriched_id lac_nm edu_lac_type_nm state])
          end
        end
      end

      context 'when client stale and cache fresh' do
        let!(:cached_response) do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_nil') do
            service.get_licenses_and_certs_v1({})
          end
        end

        it 'gets list of licenses and certifications and includes cached version' do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_fresh') do
            response = service.get_licenses_and_certs_v1({})
            expect(response.version).to eq(cached_response.version)
            lacs = response.body[:lacs]
            expect(lacs.class).to be(Array)
            expect(lacs.first.keys).to eq(%i[enriched_id lac_nm edu_lac_type_nm state])
          end
        end
      end

      context 'when client fresh and cache fresh' do
        let(:v_client) { v_fresh }

        let!(:cached_response) do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_nil') do
            service.get_licenses_and_certs_v1({})
          end
        end

        it 'returns 304 Not Modified' do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_fresh') do
            response = service.get_licenses_and_certs_v1({})
            expect(response.status).to eq(304)
            expect(response.response_headers['etag']).to eq(cached_response.version)
          end
        end
      end
    end
  end

  describe '#get_license_and_cert_details_v1' do
    context 'when versioning disabled' do
      it 'gets details for license or certification' do
        VCR.use_cassette('gi/lcpe/get_lac_details') do
          response = service.get_license_and_cert_details_v1({ id: '1@f9822' })
          lac = response.body[:lac]
          expect(lac.class).to be(Hash)
          expect(lac.keys).to eq(%i[enriched_id lac_nm edu_lac_type_nm state tests institution])
          expect(lac[:tests].class).to be(Array)
          expect(lac[:institution].class).to be(Hash)
        end
      end
    end

    context 'when versioning enabled' do
      let(:lcpe_type) { 'lacs' }

      context 'when client requests details with stale cache' do
        let(:v_client) { v_stale }

        it 'raises ClientCacheStaleError' do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_stale') do
            expect { service.get_license_and_cert_details_v1({ id: '1@f9822' }) }
              .to raise_error(LCPERedis::ClientCacheStaleError)
          end
        end
      end

      context 'when client requests details with fresh cache' do
        let(:v_client) { v_fresh }

        it 'gets details for license or certification' do
          VCR.use_cassette('gi/lcpe/get_lacs_cache_fresh') do
            VCR.use_cassette('gi/lcpe/get_lac_details') do
              response = service.get_license_and_cert_details_v1({ id: '1@f9822' })
              lac = response.body[:lac]
              expect(lac.class).to be(Hash)
              expect(lac.keys).to eq(%i[enriched_id lac_nm edu_lac_type_nm state tests institution])
              expect(lac[:tests].class).to be(Array)
              expect(lac[:institution].class).to be(Hash)
            end
          end
        end
      end
    end
    
  end

  describe '#get_exams_v1' do
    context 'when versioning disabled' do
      it 'gets list of exams' do
        VCR.use_cassette('gi/lcpe/get_exams_versioning_disabled') do
          response = service.get_exams_v1({})
          exams = response.body[:exams]
          expect(exams.class).to be(Array)
          expect(exams.first.keys).to eq(%i[enriched_id name])
        end
      end
    end
  end

  context 'when versioning enabled' do
    let(:lcpe_type) { 'exams' }

    context 'when client nil and cache nil' do
      it 'gets list of exams and includes fresh version' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
          response = service.get_exams_v1({})
          expect(response.version).not_to be_nil
          exams = response.body[:exams]
          expect(exams.class).to be(Array)
          expect(exams.first.keys).to eq(%i[enriched_id name])
        end
      end
    end

    context 'when client stale and cache stale' do
      let(:v_client) { v_stale }

      let!(:cached_response) do
        VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
          response = service.get_exams_v1({})
          response.version = v_client
          lcpe_cache.cache(lcpe_type, response)
          LCPERedis.find(lcpe_type).response
        end
      end

      it 'gets list of exams and includes fresh version' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
          response = service.get_exams_v1({})
          expect(response.version).to be > cached_response.version
          exams = response.body[:exams]
          expect(exams.class).to be(Array)
          expect(exams.first.keys).to eq(%i[enriched_id name])
        end
      end
    end

    context 'when client stale and cache fresh' do
      let!(:cached_response) do
        VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
          service.get_exams_v1({})
        end
      end

      it 'gets list of exams and includes cached version' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_fresh') do
          response = service.get_exams_v1({})
          expect(response.version).to eq(cached_response.version)
          exams = response.body[:exams]
          expect(exams.class).to be(Array)
          expect(exams.first.keys).to eq(%i[enriched_id name])
        end
      end
    end

    context 'when client fresh and cache fresh' do
      let(:v_client) { v_fresh }

      let!(:cached_response) do
        VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
          service.get_exams_v1({})
        end
      end

      it 'returns 304 Not Modified' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_fresh') do
          response = service.get_exams_v1({})
          expect(response.status).to eq(304)
          expect(response.response_headers['etag']).to eq(cached_response.version)
        end
      end
    end
  end

  # Versioning not required for exam details
  describe '#get_exam_details_v1' do
    it 'gets list of exams' do
      VCR.use_cassette('gi/lcpe/get_exam_details') do
        response = service.get_exam_details_v1({ id: '1@acce9' })
        exam = response.body[:exam]
        expect(exam.class).to be(Hash)
        expect(exam.keys).to eq(%i[enriched_id name tests institution])
        expect(exam[:tests].class).to be(Array)
        expect(exam[:institution].class).to be(Hash)
      end
    end
  end
end
