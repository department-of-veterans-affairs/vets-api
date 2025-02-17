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
      expect(klass.redis_namespace).to be_a(Redis::Namespace)
      expect(klass.redis_namespace.namespace).to eq('my_namespace')
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
      expect_any_instance_of(Redis::Namespace).to receive(:set).once.with(
        'e66fd7b7-94e0-4748-8063-283f55efb0ea',
        '{":uuid":"e66fd7b7-94e0-4748-8063-283f55efb0ea",":email":"foo@bar.com"}'
      )
      subject.save
    end

    it 'saves entry with namespace' do
      subject.save

      expect(subject.redis_namespace.redis.keys).to include('my_namespace:e66fd7b7-94e0-4748-8063-283f55efb0ea')
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

  describe '#expire' do
    it 'updates the redis ttl of the model instance' do
      subject.save
      expect(subject.ttl).to eq(60)
      subject.expire(100)
      expect(subject.ttl).to eq(100)
    end
  end

  describe '#destroy' do
    it 'removes itself from redis with the correct namespace' do
      expect_any_instance_of(Redis::Namespace).to receive(:del).once.with(
        'e66fd7b7-94e0-4748-8063-283f55efb0ea'
      )
      subject.destroy
    end

    it "entry doesn't exists" do
      subject.destroy

      expect(subject.redis_namespace.redis.keys).not_to include('my_namespace:e66fd7b7-94e0-4748-8063-283f55efb0ea')
    end

    it 'freezes the instance after destroy is called' do
      subject.destroy
      expect(subject.destroyed?).to be(true)
      expect(subject.frozen?).to be(true)
    end

    it 'duping a destroyed object returns destroyed == false, frozen == false' do
      subject.destroy
      expect(subject.dup.destroyed?).to be(false)
      expect(subject.dup.frozen?).to be(false)
      expect(subject.dup.attributes).to eq(subject.attributes)
    end

    it 'cloning a destroyed object returns destroyed == true, frozen == true' do
      subject.destroy
      expect(subject.clone.destroyed?).to be(true)
      expect(subject.clone.frozen?).to be(true)
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
