# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/response'

describe LCPERedis do
  subject { LCPERedis.new(lcpe_type:) }

  let(:lcpe_type) { 'lacs' }
  let(:fresh_response) { build(:gi_lcpe_response) }
  let(:stale_response) { build(:gi_lcpe_response, :stale) }
  let(:v_fresh) { fresh_response.version }
  let(:v_stale) { stale_response.version }
  let(:raw_response) do
    double('FaradayResponse', body: {}, status:, response_headers:, success?: success)
  end
  let(:status) { 200 }
  let(:response_headers) { { 'Etag' => v_fresh } }
  let(:success) { true }

  describe '.initialize' do
    it 'requires lcpe_type kwarg and sets attribute' do
      expect(subject.lcpe_type).to eq(lcpe_type)
    end
  end

  def load_cache(response)
    LCPERedis.new.cache(lcpe_type, response)
  end

  describe '#fresh_version_from' do
    context 'when GIDS response not modified' do
      let(:status) { 304 }

      it 'returns cached response' do
        load_cache(fresh_response)
        expect(subject.fresh_version_from(raw_response).body).to eq(fresh_response.body)
      end
    end

    context 'when GIDS response modified' do
      before do
        allow(GI::LCPE::Response).to receive(:from).with(raw_response).and_return(lcpe_response)
      end

      context 'when status 200' do
        let(:lcpe_response) { fresh_response }

        it 'invalidates cache and caches new response' do
          expect(described_class).to receive(:delete).with(lcpe_type)
          expect(fresh_response).to receive(:cache?).and_return(true)
          expect(subject.fresh_version_from(raw_response)).to eq(lcpe_response)
        end
      end

      context 'when status unsuccessful' do
        let(:lcpe_response) { build(:gi_lcpe_response, status:) }
        let(:status) { 500 }
        let(:success) { false }

        it 'returns response without caching' do
          expect(described_class).not_to receive(:delete)
          expect(lcpe_response).to receive(:cache?).and_return(false)
          expect(subject.fresh_version_from(raw_response)).to eq(lcpe_response)
        end
      end
    end
  end

  describe '#force_client_refresh_and_cache' do
    context 'when redis cache stale' do
      it 'caches gids response and raises error' do
        load_cache(stale_response)
        allow(GI::LCPE::Response).to receive(:from).with(raw_response).and_return(fresh_response)
        expect { subject.force_client_refresh_and_cache(raw_response) }
          .to change { LCPERedis.find(lcpe_type).response.version }.from(v_stale).to(v_fresh)
          .and raise_error(LCPERedis::ClientCacheStaleError)
      end
    end

    context 'when redis cache fresh' do
      it 'caches gids response and raises error' do
        load_cache(fresh_response)
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
      it 'returns cached response' do
        load_cache(fresh_response)
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
      it 'returns cached version' do
        load_cache(fresh_response)
        expect(subject.cached_version).to eq(fresh_response.version)
      end
    end
  end
end
