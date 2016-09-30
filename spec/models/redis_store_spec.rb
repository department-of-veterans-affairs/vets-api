# frozen_string_literal: true
require 'rails_helper'

describe RedisStore do
  let(:klass) do
    Class.new(RedisStore) do
      redis_store 'my_namespace'
      default_ttl 60
      attribute :uuid
      attribute :email
      alias_method redis_key uuid
    end
  end

  subject { klass.new(uuid: 'e66fd7b7-94e0-4748-8063-283f55efb0ea', email: 'foo@bar.com') }

  describe 'configuration' do
    it 'should have a configured redis namespace instance' do
      expect(klass.redis).to be_kind_of(Redis::Namespace)
      expect(klass.redis.namespace).to eq('my_namespace')
    end
  end

  describe '.find' do
    it 'finds deserialized class in redis' do
      subject.save
      found = klass.find('e66fd7b7-94e0-4748-8063-283f55efb0ea')
      expect(found).to be_a(klass)
      expect(found.uuid).to eq('e66fd7b7-94e0-4748-8063-283f55efb0ea')
      expect(found.email).to eq('foo@bar.com')
    end
  end

  describe '.exists?' do
    context 'when the model is not saved' do
      it 'returns true if the given key exists' do
        subject.save
        expect(klass.exists?('e66fd7b7-94e0-4748-8063-283f55efb0ea')).to be_truthy
      end
    end
    context 'when the model is saved' do
      it 'returns false' do
        expect(klass.exists?('e66fd7b7-94e0-4748-8063-283f55efb0ea')).to be_falsey
      end
    end
  end

  describe '#save' do
    it 'saves serialized class to redis with the correct namespace' do
      expect_any_instance_of(Redis).to receive(:set).once.with(
        'my_namespace:e66fd7b7-94e0-4748-8063-283f55efb0ea',
        '{":uuid":"e66fd7b7-94e0-4748-8063-283f55efb0ea",":email":"foo@bar.com"}'
      )
      subject.save
    end
  end

  describe '#update' do
    it 'updates only user the user attributes passed in as arguments' do
      expect(subject).to receive(:save).once
      subject.update(email: 'foo@barred.com')
      expect(subject.attributes).to eq(
        uuid: 'e66fd7b7-94e0-4748-8063-283f55efb0ea',
        email: 'foo@barred.com'
      )
    end
  end

  describe '#destroy' do
    it 'removes itself from redis with the correct namespace' do
      expect_any_instance_of(Redis).to receive(:del).once.with(
        'my_namespace:e66fd7b7-94e0-4748-8063-283f55efb0ea'
      )
      subject.destroy
    end
  end

  describe '#persisted' do
    context 'when the model is not saved' do
      it 'returns false' do
        expect(subject.persisted?).to be_falsey
      end
    end

    context 'when the model is saved' do
      it 'returns false' do
        subject.save
        expect(subject.persisted?).to be_truthy
      end
    end
  end
end
