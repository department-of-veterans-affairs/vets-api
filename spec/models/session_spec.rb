# frozen_string_literal: true

require 'rails_helper'
require 'lib/common/maximum_redis_lifetime_spec_helper'

RSpec.describe Session, type: :model do
  let(:attributes) { { uuid: 'abcd-1234' } }
  subject { described_class.new(attributes) }

  it_behaves_like 'a redis store with a maximum lifetime' do
    subject { described_class.new(attributes) }
  end

  context 'session without attributes' do
    it 'expect ttl to an Integer' do
      expect(subject.ttl).to be_an(Integer)
      expect(subject.ttl).to be_between(-Float::INFINITY, 0)
    end

    it 'assigns a token having length 40' do
      expect(subject.token.length).to eq(40)
    end

    it 'assigns a created_at timestamp' do
      expect(subject.created_at).to be_within(1.second).of(Time.now.utc)
    end

    it 'has a persisted attribute of false' do
      expect(subject.persisted?).to be_falsey
    end
  end

  describe 'redis persistence' do
    before(:each) { subject.save }

    context 'expire' do
      it 'extends a session' do
        expect(subject.expire(7200)).to eq(true)
        expect(subject.ttl).to eq(7200)
      end
    end

    context 'save' do
      it 'sets persisted flag to true' do
        expect(subject.persisted?).to be_truthy
      end

      it 'sets the ttl countdown' do
        expect(subject.ttl).to be_an(Integer)
        expect(subject.ttl).to be_between(0, 3600)
      end

      it 'will save a session within the maximum ttl' do
        subject.created_at = subject.created_at - (described_class::MAX_SESSION_LIFETIME - 1.minute)
        expect(subject.save).to eq(true)
      end

      it 'will not save a session beyond the maximum ttl' do
        subject.created_at = subject.created_at - (described_class::MAX_SESSION_LIFETIME + 1.minute)
        expect(subject.save).to eq(false)
        expect(subject.errors.messages).to include(:created_at)
      end
    end

    context 'find' do
      let(:found_session) { described_class.find(subject.token) }

      it 'can find a saved session in redis' do
        expect(found_session).to be_a(described_class)
        expect(found_session.token).to eq(subject.token)
      end

      it 'expires and returns nil if session loaded from redis is invalid' do
        allow_any_instance_of(described_class).to receive(:valid?).and_return(false)
        expect(found_session).to be_nil
      end

      it 'returns nil if session was not found' do
        expect(described_class.find('non-existant-token')).to be_nil
      end

      it 'does not change the created_at timestamp' do
        orig_created_at = found_session.created_at
        expect(found_session.save).to eq(true)
        expect(found_session.created_at).to eq(orig_created_at)
      end
    end

    context 'destroy' do
      it 'can destroy a session in redis' do
        expect(subject.destroy).to eq(1)
        expect(described_class.find(subject.token)).to be_nil
      end
    end
  end
end
