# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/response'

describe LCPERedis do
  subject { LCPERedis.new(lcpe_type:) }

  let(:lcpe_type) { 'lacs' }
  let(:raw_response) { generate_raw_response(status) }
  let(:lcpe_response) { GI::LCPE::Response.from(raw_response) }
  let(:cached_response) { GI::LCPE::Response.from(generate_raw_response(200, v_cache)) }
  let(:status) { 200 }
  let(:v_fresh) { '3' }
  let(:v_stale) { '2' }
  let(:success) { true }
  
  describe '.initialize' do
    it 'requires lcpe_type kwarg and sets attribute' do
      expect(subject.lcpe_type).to eq(lcpe_type)
    end
  end

  describe '#fresh_version_from' do
    context 'when GIDS response not modified' do
      let(:v_cache) { v_fresh }
      let(:status) { 304 }

      it 'returns cached response' do
        load_cache
        # stub Common::RedisStore.find because it instantiates new response object
        allow(subject).to receive(:cached_response).and_return(cached_response)
        expect(subject.fresh_version_from(raw_response)).to eq(cached_response)
      end
    end

    context 'when GIDS response modified' do
      before do
        allow(GI::LCPE::Response).to receive(:from).with(raw_response).and_return(lcpe_response)
      end

      context 'when status 200' do
        it 'invalidates cache and caches new response' do
          expect(described_class).to receive(:delete).with(lcpe_type)
          expect(lcpe_response).to receive(:cache?).and_return(true)
          expect(subject.fresh_version_from(raw_response)).to eq(lcpe_response)
        end
      end

      context 'when status unsuccessful ' do
        let(:status) { 500 }
        let(:success) { false }
  
        it 'invalidates cache and caches new response' do
          expect(described_class).not_to receive(:delete)
          expect(lcpe_response).to receive(:cache?).and_return(false)
          subject.fresh_version_from(raw_response)
        end
      end
    end
  end

  describe '#force_client_refresh_and_cache' do
    before do
      load_cache
      allow(subject).to receive(:cached_response).and_return(cached_response)
    end

    context 'when redis cache stale' do
      let(:v_cache) { v_stale }

      it 'caches gids response and raises error' do
        allow(GI::LCPE::Response).to receive(:from).with(raw_response).and_return(lcpe_response)
        expect(subject).to receive(:cache).with(lcpe_type, lcpe_response)
        expect { subject.force_client_refresh_and_cache(raw_response) }
          .to raise_error(LCPERedis::ClientCacheStaleError)
      end
    end

    context 'when redis cache fresh' do
      let(:v_cache) { v_fresh }

      it 'caches gids response and raises error' do
        expect(subject).not_to receive(:cache).with(lcpe_type, lcpe_response)
        expect { subject.force_client_refresh_and_cache(raw_response) }
          .to raise_error(LCPERedis::ClientCacheStaleError)
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
      let(:v_cache) { v_fresh }

      it 'returns cached response' do
        load_cache
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
      let(:v_cache) { v_fresh }

      it 'returns cached version' do
        load_cache
        expect(subject.cached_version).to eq(v_cache)
      end
    end
  end

  def generate_raw_response(status, version = v_fresh)
    response_headers = { 'Etag' => version }
    double('FaradayResponse', body: {}, status:, response_headers:, success?: success )
  end

  def load_cache
    LCPERedis.new.cache(lcpe_type, cached_response)
  end
end
