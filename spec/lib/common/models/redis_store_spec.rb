# frozen_string_literal: true

require 'rails_helper'
require 'common/models/redis_store'

describe Common::RedisStore do
  let(:klass) do
    Class.new(Common::RedisStore) do
      redis_store 'my_namespace'
      redis_ttl 60
      redis_key :uuid

      attribute :uuid
      attribute :email
    end
  end

  subject { klass.new(uuid: 'e66fd7b7-94e0-4748-8063-283f55efb0ea', email: 'foo@bar.com') }

  describe 'configuration' do
    it 'should have a configured redis namespace instance' do
      expect(klass.redis_namespace).to be_kind_of(Redis::Namespace)
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
      expect_any_instance_of(Redis).to receive(:del).once.with(
        'my_namespace:e66fd7b7-94e0-4748-8063-283f55efb0ea'
      )
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
