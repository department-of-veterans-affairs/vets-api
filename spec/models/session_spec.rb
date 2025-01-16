# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session, type: :model do
  subject { described_class.new(attributes) }

  let(:attributes) { { uuid: 'abcd-1234' } }

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
      expect(subject).not_to be_persisted
    end

    context 'with a matching user' do
      let(:start_time) { Time.current.utc }
      let(:expry_time) { start_time + 1800 }
      let(:user) { create(:user, :mhv, uuid: attributes[:uuid]) }

      before do
        Timecop.freeze(start_time)
        user
        subject.save # persisting it to freeze the ttl
      end

      after do
        Timecop.return
      end

      it '#ttl_in_time returns ttl of the session' do
        expect(subject.ttl_in_time).to eq(expry_time)
      end
    end
  end

  describe 'redis persistence' do
    before { subject.save }

    context 'expire' do
      it 'extends a session' do
        expect(subject.expire(3600)).to be(true)
        expect(subject.ttl).to eq(3600)
      end

      it 'extends the session when within maximum ttl' do
        subject.created_at = subject.created_at - (described_class::MAX_SESSION_LIFETIME - 1.minute)
        expect(subject.expire(1800)).to be(true)
      end

      it 'does not extend the session when beyond the maximum ttl' do
        subject.created_at = subject.created_at - (described_class::MAX_SESSION_LIFETIME + 1.minute)
        expect(subject.expire(1800)).to be(false)
        expect(subject.errors.messages).to include(:created_at)
      end

      it 'allows for continuous session extension up to the maximum' do
        start_time = Time.current
        Timecop.freeze(start_time)

        # keep extending session so Redis doesn't kill it while remaining
        # within Sesion::MAX_SESSION_LIFETIME
        increment = subject.redis_namespace_ttl - 60.seconds
        max_hours = described_class::MAX_SESSION_LIFETIME / 1800.seconds
        (1..max_hours).each do |hour|
          Timecop.freeze(start_time + (increment * hour))
          expect(subject.expire(described_class.redis_namespace_ttl)).to be(true)
          expect(subject.ttl).to eq(described_class.redis_namespace_ttl)
        end

        # now outside Session::MAX_SESSION_LIFETIME
        Timecop.freeze(start_time + (increment * max_hours) + increment)
        expect(subject.expire(described_class.redis_namespace_ttl)).to be(false)
        expect(subject.errors.messages).to include(:created_at)

        Timecop.return
      end
    end

    context 'save' do
      it 'sets persisted flag to true' do
        expect(subject).to be_persisted
      end

      it 'sets the ttl countdown' do
        expect(subject.ttl).to be_an(Integer)
        expect(subject.ttl).to be_between(0, 3600)
      end

      it 'saves a session within the maximum ttl' do
        subject.created_at = subject.created_at - (described_class::MAX_SESSION_LIFETIME - 1.minute)
        expect(subject.save).to be(true)
      end

      context 'when beyond the maximum ttl' do
        before { subject.created_at = subject.created_at - (described_class::MAX_SESSION_LIFETIME + 1.minute) }

        it 'does not save' do
          expect(subject.save).to be(false)
          expect(subject.errors.messages).to include(:created_at)
        end

        it 'logs info to sentry' do
          expect(subject).to receive(:log_message_to_sentry).with(
            'Maximum Session Duration Reached',
            :info,
            {},
            session_token: described_class.obscure_token(subject.token)
          )
          subject.save
        end
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
        expect(described_class.find('non-existent-token')).to be_nil
      end

      it 'does not change the created_at timestamp' do
        orig_created_at = found_session.created_at
        expect(found_session.save).to be(true)
        expect(found_session.created_at).to eq(orig_created_at)
      end
    end

    context 'destroy' do
      it 'can destroy a session in redis' do
        expect(subject.destroy).to eq(1)
        expect(described_class.find(subject.token)).to be_nil
      end
    end

    context 'authenticated_by_ssoe' do
      let(:transaction_session) { described_class.new({ uuid: 'a', ssoe_transactionid: 'b' }) }

      it 'is false when no transaction attribute is provided' do
        expect(subject.authenticated_by_ssoe).to be_falsey
      end

      it 'is true when a transaction attribute is provided' do
        expect(transaction_session.authenticated_by_ssoe).to be_truthy
      end
    end
  end
end
