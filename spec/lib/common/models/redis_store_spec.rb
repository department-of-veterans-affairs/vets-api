# frozen_string_literal: true

require 'rails_helper'
require 'common/models/redis_store'

describe Common::RedisStore do
  subject { klass.new(uuid: 'e66fd7b7-94e0-4748-8063-283f55efb0ea', email: 'foo@bar.com') }

  let(:klass) do
    Class.new(Common::RedisStore) do
      redis_store 'my_namespace'
      redis_ttl 60
      redis_key :uuid

      attribute :uuid
      attribute :email
    end
  end

  describe 'configuration' do
    it 'has a configured redis namespace instance' do
      expect(klass.redis_namespace).to be_kind_of(Redis::Namespace)
      expect(klass.redis_namespace.namespace).to eq('my_namespace')

      expect(klass.other_redis).to be_kind_of(Redis::Namespace)
      expect(klass.other_redis.namespace).to eq('my_namespace')
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

  describe '.pop' do
    it 'finds deserialized class in redis and removes' do
      subject.save
      found = klass.pop('e66fd7b7-94e0-4748-8063-283f55efb0ea')
      expect(found).to be_a(klass)
      expect(found.uuid).to eq('e66fd7b7-94e0-4748-8063-283f55efb0ea')
      expect(found.email).to eq('foo@bar.com')
      expect(klass).not_to exist('e66fd7b7-94e0-4748-8063-283f55efb0ea')
    end
  end

  describe '.exists?' do
    context 'when the model is not saved' do
      it 'returns true if the given key exists' do
        subject.save
        expect(klass).to exist('e66fd7b7-94e0-4748-8063-283f55efb0ea')
      end
    end

    context 'when the model is saved' do
      it 'returns false' do
        expect(klass).not_to exist('e66fd7b7-94e0-4748-8063-283f55efb0ea')
      end
    end
  end

  describe '#save' do
    it 'saves serialized class to redis with the correct namespace' do
      expected_key = 'my_namespace:e66fd7b7-94e0-4748-8063-283f55efb0ea'
      expected_val = '{":uuid":"e66fd7b7-94e0-4748-8063-283f55efb0ea",":email":"foo@bar.com"}'

      expect(VetsApiRedis.current).to receive(:set).once.with(expected_key, expected_val)
      expect(VetsApiRedis.other_redis).to receive(:set).once.with(expected_key, expected_val)
      subject.save
    end
  end

  describe '#update' do
    it 'updates only user the user attributes passed in as arguments' do
      subject.update(email: 'foo@barred.com')
      expect(subject.attributes).to eq(
        uuid: 'e66fd7b7-94e0-4748-8063-283f55efb0ea',
        email: 'foo@barred.com'
      )
      expect(subject.redis_namespace.get(subject.uuid)).to eq(
        '{":uuid":"e66fd7b7-94e0-4748-8063-283f55efb0ea",":email":"foo@barred.com"}'
      )
      expect(subject.other_redis.get(subject.uuid)).to eq(
        '{":uuid":"e66fd7b7-94e0-4748-8063-283f55efb0ea",":email":"foo@barred.com"}'
      )
    end
  end

  describe '#expire' do
    it 'updates the redis ttl of the model instance' do
      subject.save
      expect(subject.ttl).to eq(60)
      expect(subject.other_redis.ttl(subject.uuid)).to eq(60)
      subject.expire(100)
      expect(subject.ttl).to eq(100)
      expect(subject.other_redis.ttl(subject.uuid)).to eq(100)
    end
  end

  describe '#destroy' do
    it 'removes itself from redis with the correct namespace' do
      expected_redis_key = 'my_namespace:e66fd7b7-94e0-4748-8063-283f55efb0ea'

      expect(VetsApiRedis.current).to receive(:del).once.with(expected_redis_key)
      expect(VetsApiRedis.other_redis).to receive(:del).once.with(expected_redis_key)
      subject.destroy
    end

    it 'freezes the instance after destroy is called' do
      subject.destroy
      expect(subject.destroyed?).to eq(true)
      expect(subject.frozen?).to eq(true)
    end

    it 'duping a destroyed object returns destroyed == false, frozen == false' do
      subject.destroy
      expect(subject.dup.destroyed?).to eq(false)
      expect(subject.dup.frozen?).to eq(false)
      expect(subject.dup.attributes).to eq(subject.attributes)
    end

    it 'cloning a destroyed object returns destroyed == true, frozen == true' do
      subject.destroy
      expect(subject.clone.destroyed?).to eq(true)
      expect(subject.clone.frozen?).to eq(true)
      expect(subject.clone.attributes).to eq(subject.attributes)
    end
  end

  describe '#persisted' do
    context 'when the model is not saved' do
      it 'returns false' do
        expect(subject).not_to be_persisted
      end
    end

    context 'when the model is saved' do
      it 'returns false' do
        subject.save
        expect(subject).to be_persisted
      end
    end
  end
end
