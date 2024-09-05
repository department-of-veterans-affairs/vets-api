# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'

RSpec.describe Sidekiq::AttrPackage do
  let(:redis_double) { instance_double(Redis::Namespace) }

  before do
    allow(Redis::Namespace).to receive(:new).and_return(redis_double)
  end

  after do
    described_class.instance_variable_set(:@redis, nil)
  end

  describe '.create' do
    let(:attrs) { { foo: 'bar' } }
    let(:expected_key) { SecureRandom.hex(32) }

    before do
      allow(redis_double).to receive(:set)
      allow(SecureRandom).to receive(:hex).and_return(expected_key)
    end

    context 'when no expiration is provided' do
      it 'stores attributes in Redis and returns a key' do
        expect(redis_double).to receive(:set).with(expected_key, attrs.to_json, ex: 7.days)
        key = described_class.create(**attrs)
        expect(key).to eq(expected_key)
      end
    end

    context 'when an expiration is provided' do
      let(:expires_in) { 1.day }

      it 'stores attributes in Redis and returns a key' do
        expect(redis_double).to receive(:set).with(expected_key, attrs.to_json, ex: expires_in)
        key = described_class.create(expires_in:, **attrs)
        expect(key).to eq(expected_key)
      end
    end

    context 'when an error occurs' do
      let(:expected_error_message) { '[Sidekiq] [AttrPackage] create error: Redis error' }

      before do
        allow(redis_double).to receive(:set).and_raise('Redis error')
      end

      it 'raises an AttrPackageError' do
        expect do
          described_class.create(**attrs)
        end.to raise_error(Sidekiq::AttrPackageError).with_message(expected_error_message)
      end
    end
  end

  describe '.find' do
    let(:key) { 'some_key' }

    before do
      allow(redis_double).to receive(:get)
    end

    context 'when the key exists' do
      let(:attrs) { { foo: 'bar' } }

      before do
        allow(redis_double).to receive(:get).with(key).and_return(attrs.to_json)
      end

      it 'retrieves the attribute package from Redis' do
        result = described_class.find(key)
        expect(result).to eq(attrs)
      end
    end

    context 'when the key does not exist' do
      before do
        allow(redis_double).to receive(:get).with(key).and_return(nil)
      end

      it 'returns nil' do
        expect(described_class.find(key)).to be_nil
      end
    end

    context 'when an error occurs' do
      let(:expected_error_message) { '[Sidekiq] [AttrPackage] find error: Redis error' }

      before do
        allow(redis_double).to receive(:get).with(key).and_raise('Redis error')
      end

      it 'raises an AttrPackageError' do
        expect do
          described_class.find(key)
        end.to raise_error(Sidekiq::AttrPackageError).with_message(expected_error_message)
      end
    end
  end

  describe '.delete' do
    let(:key) { 'some_key' }

    before do
      allow(redis_double).to receive(:del)
    end

    it 'deletes the attribute package from Redis' do
      expect(redis_double).to receive(:del).with(key)
      described_class.delete(key)
    end

    context 'when an error occurs' do
      let(:expected_error_message) { '[Sidekiq] [AttrPackage] delete error: Redis error' }

      before do
        allow(redis_double).to receive(:del).with(key).and_raise('Redis error')
      end

      it 'raises an AttrPackageError' do
        expect do
          described_class.delete(key)
        end.to raise_error(Sidekiq::AttrPackageError).with_message(expected_error_message)
      end
    end
  end
end
