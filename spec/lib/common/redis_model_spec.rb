# frozen_string_literal: true

require 'rails_helper'
require 'common/redis_model'

RSpec.describe Common::RedisModel do
  subject { klass.new(valid_attributes) }

  let(:klass) do
    Class.new(Common::RedisModel) do
      redis_store :test_redis_model
      redis_key :id
      redis_ttl 60

      attribute :id, :string
      attribute :name, :string
      attribute :role, :string

      validates :id, presence: true
      validates :name, presence: true
    end
  end

  let(:redis_namespace) { Redis::Namespace.new(:test_redis_model, redis: $redis) }
  let(:valid_attributes) { { id: 'user:123', name: 'Alice' } }

  before do
    stub_const('TestRedisModel', klass)
    redis_namespace.flushdb
  end

  shared_examples 'a redis-persisted model' do
    it 'is persisted after save' do
      subject.save
      expect(subject).to be_persisted
    end

    it 'can be found by ID' do
      subject.save
      found = klass.find(subject.id)
      expect(found).to be_a(klass)
      expect(found.id).to eq(subject.id)
      expect(found.name).to eq(subject.name)
    end
  end

  describe '.create and .find' do
    it_behaves_like 'a redis-persisted model'

    it 'raises an error if record is not found' do
      expect { klass.find('nonexistent') }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'returns nil from find_by if key does not exist' do
      expect(klass.find_by('nonexistent')).to be_nil
    end
  end

  describe '#save and #save!' do
    it 'persists valid objects' do
      expect(subject.save).to be true
      found = klass.find(subject.id)
      expect(found.name).to eq('Alice')
    end

    it 'returns false and adds errors when invalid' do
      invalid = klass.new(id: nil, name: nil)
      expect(invalid.save).to be false
      expect(invalid.errors[:id]).to include("can't be blank")
      expect(invalid.errors[:name]).to include("can't be blank")
    end

    it 'raises on save! when invalid' do
      invalid = klass.new(name: nil)
      expect { invalid.save! }.to raise_error(ActiveModel::ValidationError)
    end
  end

  describe '#update and #update!' do
    before { subject.save }

    it 'updates attributes and persists' do
      subject.update(name: 'New')
      found = klass.find(subject.id)
      expect(found.name).to eq('New')
    end

    it 'raises on update! if invalid' do
      expect { subject.update!(name: nil) }.to raise_error(ActiveModel::ValidationError)
    end
  end

  describe '#destroy and #destroy!' do
    before { subject.save }

    it 'deletes the record from Redis' do
      subject.destroy
      expect(klass.find_by(subject.id)).to be_nil
      expect(subject).to be_destroyed
    end

    it 'raises on destroy! if record does not exist' do
      unsaved = klass.new(id: 'missing', name: 'Ghost')
      expect { unsaved.destroy! }.to raise_error(RuntimeError, /Unable to destroy/)
    end
  end

  describe '#computed' do
    it 'returns the value if present' do
      expect(subject.computed(:name)).to eq('Alice')
    end

    it 'returns fallback if value is blank' do
      klass.computed_fallbacks(role: 'guest')
      no_role = klass.new(id: 'comp:2', name: 'No Role')
      expect(no_role.computed(:role)).to eq('guest')
    end
  end

  describe '.keys and .exists?' do
    before do
      klass.create(id: 'key1', name: 'Test1')
      klass.create(id: 'key2', name: 'Test2')
    end

    it 'returns the correct Redis keys' do
      expect(klass.keys).to include('key1', 'key2')
    end

    it 'checks if a key exists' do
      expect(klass.exists?('key1')).to be true
      expect(klass.exists?('missing')).to be false
    end
  end
end
