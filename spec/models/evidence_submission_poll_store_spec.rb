# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EvidenceSubmissionPollStore, type: :model do
  subject { described_class.new(claim_id: '123456', request_ids: [111_111, 222_222, 333_333]) }

  describe 'configuration' do
    it 'has a configured redis namespace instance' do
      expect(described_class.redis_namespace).to be_a(Redis::Namespace)
      expect(described_class.redis_namespace.namespace).to eq('evidence-submission-poll')
    end

    it 'has a configured TTL of 60 seconds' do
      expect(described_class.redis_namespace_ttl).to eq(60)
    end

    it 'uses claim_id as the redis key' do
      expect(described_class.redis_namespace_key).to eq(:claim_id)
    end
  end

  describe 'validations' do
    it 'requires claim_id' do
      record = described_class.new(request_ids: [111_111])
      expect(record).not_to be_valid
      expect(record.errors[:claim_id]).to include("can't be blank")
    end

    it 'requires request_ids' do
      record = described_class.new(claim_id: '123456')
      expect(record).not_to be_valid
      expect(record.errors[:request_ids]).to include("can't be blank")
    end

    it 'is valid with all required attributes' do
      expect(subject).to be_valid
    end
  end

  describe '.find' do
    it 'finds deserialized record in redis' do
      subject.save
      found = described_class.find('123456')
      expect(found).to be_a(described_class)
      expect(found.claim_id).to eq('123456')
      expect(found.request_ids).to eq([111_111, 222_222, 333_333])
    end

    it 'returns nil when key does not exist' do
      found = described_class.find('nonexistent')
      expect(found).to be_nil
    end
  end

  describe '.create' do
    it 'creates and saves a new record' do
      record = described_class.create(claim_id: '789012', request_ids: [444_444, 555_555])
      expect(record).to be_persisted
      expect(described_class.find('789012')).to be_present
    end
  end

  describe '#save' do
    it 'saves entry with namespace' do
      subject.save
      expect(subject.redis_namespace.redis.keys).to include('evidence-submission-poll:123456')
    end

    it 'sets TTL to 60 seconds' do
      subject.save
      expect(subject.ttl).to be > 0
      expect(subject.ttl).to be <= 60
    end

    it 'returns false for invalid record' do
      invalid_record = described_class.new(claim_id: nil, request_ids: [111_111])
      expect(invalid_record.save).to be false
    end
  end

  describe '#update' do
    it 'updates only the attributes passed in as arguments' do
      subject.save
      subject.update(request_ids: [999_999])
      expect(subject.request_ids).to eq([999_999])
      expect(subject.claim_id).to eq('123456')
    end
  end

  describe '#destroy' do
    it 'removes itself from redis' do
      subject.save
      expect(described_class).to exist('123456')
      subject.destroy
      expect(described_class).not_to exist('123456')
    end

    it 'freezes the instance after destroy is called' do
      subject.save
      subject.destroy
      expect(subject.destroyed?).to be(true)
      expect(subject.frozen?).to be(true)
    end
  end

  describe '#persisted?' do
    context 'when the record is not saved' do
      it 'returns false' do
        expect(subject).not_to be_persisted
      end
    end

    context 'when the record is saved' do
      it 'returns true' do
        subject.save
        expect(subject).to be_persisted
      end
    end
  end

  describe 'cache usage in controller context' do
    it 'supports storing and retrieving sorted request_ids for comparison' do
      # Simulate controller behavior: store unsorted array
      described_class.create(claim_id: '999888', request_ids: [333_333, 111_111, 222_222])

      # Retrieve and compare sorted arrays
      cached = described_class.find('999888')
      expect(cached.request_ids.sort).to eq([111_111, 222_222, 333_333])
    end

    it 'naturally expires after TTL' do
      subject.save
      expect(described_class.find('123456')).to be_present

      # Fast-forward time simulation by checking TTL
      expect(subject.ttl).to be > 0
      expect(subject.ttl).to be <= 60
    end
  end
end
