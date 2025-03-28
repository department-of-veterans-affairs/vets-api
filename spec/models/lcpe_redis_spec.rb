# frozen_string_literal: true

require 'rails_helper'

describe LCPERedis do
  subject { LCPERedis.new(lcpe_type:) }

  let(:lcpe_type) { 'lacs' }
  let(:v_fresh) { '3' }
  let(:v_stale) { '2' }
  let(:response_headers) { { 'Etag' => "W/\"#{v_fresh}\"" } }
  let(:raw_response) { generate_response_double(200) }
  let(:cached_response) { GI::LCPE::Response.from(generate_response_double(200)) }

  def generate_response_double(status, headers = response_headers)
    double('FaradayResponse', body: { lacs: [] }, status:, response_headers: headers)
  end

  describe '.initialize' do
    it 'requires lcpe_type kwarg and sets attribute' do
      expect(subject.lcpe_type).to eq(lcpe_type)
    end
  end

  describe '#fresh_version_from' do
    context 'when GIDS response not modified' do
      let(:raw_response) { generate_response_double(304) }

      before { LCPERedis.new.cache(lcpe_type, cached_response) }

      it 'returns cached response' do
        expect(described_class).not_to receive(:delete)
        expect(subject.fresh_version_from(raw_response).version).to eq(cached_response.version)
      end
    end

    context 'when GIDS response modified' do
      context 'when status 200' do
        before { allow(GI::LCPE::Response).to receive(:from).with(raw_response).and_return(cached_response) }

        it 'invalidates cache and caches new response' do
          expect(described_class).to receive(:delete).with(lcpe_type)
          expect(cached_response).to receive(:cache?).and_return(true)
          expect(subject.fresh_version_from(raw_response).version).to eq(cached_response.version)
        end
      end
    end
  end

  describe '#force_client_refresh_and_cache' do
    before { LCPERedis.new.cache(lcpe_type, cached_response) }

    context 'when redis cache stale' do
      let(:stale_headers) { { 'Etag' => "W/\"#{v_stale}\"" } }
      let(:cached_response) { GI::LCPE::Response.from(generate_response_double(200, stale_headers)) }

      it 'caches gids response and raises error' do
        expect { subject.force_client_refresh_and_cache(raw_response) }
          .to change { LCPERedis.find(lcpe_type).response.version }.from(v_stale).to(v_fresh)
          .and raise_error(LCPERedis::ClientCacheStaleError)
      end
    end

    context 'when redis cache fresh' do
      it 'raises error without caching response' do
        expect { subject.force_client_refresh_and_cache(raw_response) }
          .to not_change { LCPERedis.find(lcpe_type).response.version }
          .and raise_error(LCPERedis::ClientCacheStaleError)
      end
    end
  end

  describe '#cached_response' do
    context 'when cache nil' do
      it 'returns nil' do
        expect(subject.cached_response).to be_nil
      end
    end

    context 'when cache present' do
      before { LCPERedis.new.cache(lcpe_type, cached_response) }

      it 'returns cached response' do
        expect(subject.cached_response).to be_a GI::LCPE::Response
      end
    end
  end

  describe '#cached_version' do
    context 'when cache nil' do
      it 'returns nil' do
        expect(subject.cached_version).to be_nil
      end
    end

    context 'when cache present' do
      before { LCPERedis.new.cache(lcpe_type, cached_response) }

      it 'returns cached version' do
        expect(subject.cached_version).to eq(cached_response.version)
      end
    end
  end
end
