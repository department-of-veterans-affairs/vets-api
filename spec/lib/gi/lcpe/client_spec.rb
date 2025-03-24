# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/client'
require 'gi/lcpe/response'

describe GI::LCPE::Client do
  let(:client) { described_class.new(v_client:, lcpe_type:) }
  let(:v_fresh) { '3' }
  let(:v_stale) { '2' }
  let(:enriched_id) { "1v#{v_client}" }

  describe '#get_licenses_and_certs_v1' do
    context 'when versioning disabled' do
      let(:v_client) { nil }
      let(:lcpe_type) { nil }

      it 'defaults to GI::GIDSResponse' do
        VCR.use_cassette('gi/lcpe/get_lacs_versioning_disabled') do
          allow(GI::GIDSResponse).to receive(:new)
          client.get_licenses_and_certs_v1({ state: 'MT' })
          expect(GI::GIDSResponse).to have_received(:new)
        end
      end
    end

    context 'when versioning enabled' do
      let(:v_client) { v_fresh }
      let(:lcpe_type) { 'lacs' }

      it 'defaults to GI::LCPE::Response' do
        VCR.use_cassette('gi/lcpe/get_lacs_cache_nil') do
          allow(GI::LCPE::Response).to receive(:new).and_call_original
          client.get_licenses_and_certs_v1({})
          expect(GI::LCPE::Response).to have_received(:new)
        end
      end
    end
  end

  describe '#get_license_and_cert_details_v1' do
    let(:response) { instance_double(GI::GIDSResponse) }
    let(:lcpe_type) { 'lacs' }

    before do
      allow(GI::GIDSResponse).to receive(:new).and_return(response)
      allow(response).to receive(:body)
    end

    context 'when client version stale' do
      let(:v_client) { v_stale }

      it 'raises ClientCacheStaleError' do
        VCR.use_cassette('gi/lcpe/get_lacs_cache_stale') do
          expect { client.get_license_and_cert_details_v1({ id: enriched_id }) }
            .to raise_error(LCPERedis::ClientCacheStaleError)
        end
      end
    end

    context 'when client version fresh' do
      let(:v_client) { v_fresh }

      it 'creates GI::GIDSReponse and calls body' do
        VCR.use_cassette('gi/lcpe/get_lacs_cache_fresh') do
          VCR.use_cassette('gi/lcpe/get_lac_details') do
            client.get_license_and_cert_details_v1({ id: enriched_id })
            expect(GI::GIDSResponse).to have_received(:new)
            expect(response).to have_received(:body)
          end
        end
      end
    end
  end

  describe '#get_exams_v1' do
    context 'when versioning disabled' do
      let(:v_client) { nil }
      let(:lcpe_type) { nil }

      it 'defaults to GI::GIDSResponse' do
        VCR.use_cassette('gi/lcpe/get_exams_versioning_disabled') do
          allow(GI::GIDSResponse).to receive(:new)
          client.get_exams_v1({ state: 'MT' })
          expect(GI::GIDSResponse).to have_received(:new)
        end
      end
    end

    context 'when versioning enabled' do
      let(:v_client) { v_fresh }
      let(:lcpe_type) { 'exams' }

      it 'defaults to GI::LCPE::Response' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_nil') do
          allow(GI::LCPE::Response).to receive(:new).and_call_original
          client.get_exams_v1({})
          expect(GI::LCPE::Response).to have_received(:new)
        end
      end
    end
  end

  describe '#get_exam_details_v1' do
    let(:response) { instance_double(GI::GIDSResponse) }
    let(:lcpe_type) { 'exams' }

    before do
      allow(GI::GIDSResponse).to receive(:new).and_return(response)
      allow(response).to receive(:body)
    end

    context 'when client version stale' do
      let(:v_client) { v_stale }

      it 'raises ClientCacheStaleError' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_stale') do
          expect { client.get_exam_details_v1({ id: enriched_id }) }
            .to raise_error(LCPERedis::ClientCacheStaleError)
        end
      end
    end

    context 'when client version fresh' do
      let(:v_client) { v_fresh }

      it 'creates GI::GIDSReponse and calls body' do
        VCR.use_cassette('gi/lcpe/get_exams_cache_fresh') do
          VCR.use_cassette('gi/lcpe/get_exam_details') do
            client.get_exam_details_v1({ id: enriched_id })
            expect(GI::GIDSResponse).to have_received(:new)
            expect(response).to have_received(:body)
          end
        end
      end
    end
  end
end
