# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailVerificationRateLimited, type: :controller do
  let(:test_controller_class) do
    Class.new(ApplicationController) do
      include EmailVerificationRateLimited

      attr_reader :current_user, :response

      def initialize(user = nil, response = nil)
        super()
        @current_user = user
        @response = response
      end
    end
  end

  let(:user) { build(:user, :loa3, uuid: 'test-uuid-123') }
  let(:response) { double('response', headers: {}) }
  let(:controller) { test_controller_class.new(user, response) }
  let(:redis_client) { instance_double(Redis::Namespace) }

  before do
    allow(controller).to receive(:verification_redis).and_return(redis_client)
    allow(redis_client).to receive_messages(
      multi: redis_client,
      incr: 1,
      expire: nil,
      del: nil,
      get: '0',
      ttl: 0
    )
    allow(redis_client).to receive(:multi).and_yield(redis_client)
    allow(Rails.logger).to receive(:warn)
    allow(StatsD).to receive(:increment)
  end

  describe 'VERIFICATION_EMAIL_LIMITS constant' do
    it 'has correct configuration' do
      expect(described_class::VERIFICATION_EMAIL_LIMITS).to eq({
                                                                 per_period: 1,
                                                                 period: 5.minutes,
                                                                 daily_limit: 5,
                                                                 daily_period: 24.hours,
                                                                 redis_namespace: 'email_verification_rate_limit'
                                                               })
    end
  end

  describe '#email_verification_rate_limit_exceeded?' do
    context 'when neither limit is exceeded' do
      before do
        allow(controller).to receive_messages(
          verification_period_count: 0,
          verification_daily_count: 3
        )
      end

      it 'returns false' do
        expect(controller.email_verification_rate_limit_exceeded?).to be false
      end
    end

    context 'when period limit is exceeded' do
      before do
        allow(controller).to receive_messages(
          verification_period_count: 1,
          verification_daily_count: 3
        )
      end

      it 'returns true' do
        expect(controller.email_verification_rate_limit_exceeded?).to be true
      end
    end

    context 'when daily limit is exceeded' do
      before do
        allow(controller).to receive_messages(
          verification_period_count: 0,
          verification_daily_count: 5
        )
      end

      it 'returns true' do
        expect(controller.email_verification_rate_limit_exceeded?).to be true
      end
    end

    context 'when both limits are exceeded' do
      before do
        allow(controller).to receive_messages(
          verification_period_count: 2,
          verification_daily_count: 6
        )
      end

      it 'returns true' do
        expect(controller.email_verification_rate_limit_exceeded?).to be true
      end
    end
  end

  describe '#enforce_email_verification_rate_limit!' do
    context 'when rate limit not exceeded' do
      before do
        allow(controller).to receive(:email_verification_rate_limit_exceeded?).and_return(false)
      end

      it 'does not raise an exception' do
        expect { controller.enforce_email_verification_rate_limit! }.not_to raise_error
      end
    end

    context 'when rate limit exceeded' do
      before do
        allow(controller).to receive_messages(
          email_verification_rate_limit_exceeded?: true,
          time_until_next_verification_allowed: 240
        )
        allow(controller).to receive_messages(
          get_email_verification_rate_limit_info: {
            period_count: 1,
            daily_count: 3,
            max_per_period: 1,
            max_daily: 5,
            period_minutes: 5,
            time_until_next_email: 240
          },
          build_verification_rate_limit_message: 'Rate limit exceeded message'
        )
      end

      it 'raises TooManyRequests exception' do
        expect { controller.enforce_email_verification_rate_limit! }
          .to raise_error(Common::Exceptions::TooManyRequests)
      end

      it 'sets Retry-After header' do
        expect(response.headers).to receive(:[]=).with('Retry-After', '240')

        expect { controller.enforce_email_verification_rate_limit! }
          .to raise_error(Common::Exceptions::TooManyRequests)
      end

      it 'logs the rate limit denial' do
        expect(controller).to receive(:log_email_verification_rate_limit_denial)

        expect { controller.enforce_email_verification_rate_limit! }
          .to raise_error(Common::Exceptions::TooManyRequests)
      end

      context 'when response is not defined' do
        let(:controller_no_response) { test_controller_class.new(user, nil) }

        before do
          allow(controller_no_response).to receive_messages(
            verification_redis: redis_client,
            email_verification_rate_limit_exceeded?: true,
            time_until_next_verification_allowed: 240,
            log_email_verification_rate_limit_denial: nil
          )
          allow(controller_no_response).to receive_messages(
            get_email_verification_rate_limit_info: {
              period_count: 1,
              daily_count: 3,
              max_per_period: 1,
              max_daily: 5,
              period_minutes: 5,
              time_until_next_email: 240
            },
            build_verification_rate_limit_message: 'Rate limit exceeded message'
          )
        end

        it 'does not attempt to set headers and still raises exception' do
          expect { controller_no_response.enforce_email_verification_rate_limit! }
            .to raise_error(Common::Exceptions::TooManyRequests)
        end
      end
    end

    context 'when Redis connection error occurs' do
      before do
        allow(controller).to receive(:email_verification_rate_limit_exceeded?)
          .and_raise(Redis::BaseConnectionError.new('Connection failed'))
      end

      it 'gracefully handles Redis connection error and does not raise exception' do
        expect { controller.enforce_email_verification_rate_limit! }.not_to raise_error
      end

      it 'logs the Redis connection error' do
        expect(Rails.logger).to receive(:warn)
          .with('Redis connection error in email verification rate limit enforcement',
                { error: 'Connection failed' })

        controller.enforce_email_verification_rate_limit!
      end

      it 'returns nil when Redis error occurs' do
        result = controller.enforce_email_verification_rate_limit!
        expect(result).to be_nil
      end
    end
  end

  describe '#increment_email_verification_rate_limit!' do
    it 'increments period counter with expiry using atomic operations' do
      expect(redis_client).to receive(:multi).and_yield(redis_client)
      expect(redis_client).to receive(:incr).with('test-uuid-123:email_verification:period')
      expect(redis_client).to receive(:expire).with('test-uuid-123:email_verification:period', 300)
      expect(redis_client).to receive(:incr).with('test-uuid-123:email_verification:daily')
      expect(redis_client).to receive(:expire).with('test-uuid-123:email_verification:daily', 86_400)

      controller.increment_email_verification_rate_limit!
    end

    it 'clears rate limit cache' do
      allow(redis_client).to receive(:multi).and_yield(redis_client)
      allow(redis_client).to receive(:incr)
      allow(redis_client).to receive(:expire)

      expect(controller).to receive(:clear_verification_rate_limit_cache)

      controller.increment_email_verification_rate_limit!
    end

    context 'when Redis connection error occurs' do
      before do
        allow(redis_client).to receive(:multi).and_raise(Redis::BaseConnectionError.new('Connection failed'))
      end

      it 'gracefully handles Redis connection error and does not raise exception' do
        expect { controller.increment_email_verification_rate_limit! }.not_to raise_error
      end

      it 'logs the Redis connection error' do
        expect(Rails.logger).to receive(:warn)
          .with('Redis connection error in email verification rate limit increment',
                { error: 'Connection failed' })

        controller.increment_email_verification_rate_limit!
      end

      it 'returns nil when Redis error occurs' do
        result = controller.increment_email_verification_rate_limit!
        expect(result).to be_nil
      end
    end
  end

  describe '#reset_email_verification_rate_limit!' do
    it 'deletes both Redis keys' do
      expect(redis_client).to receive(:del)
        .with('test-uuid-123:email_verification:period', 'test-uuid-123:email_verification:daily')

      controller.reset_email_verification_rate_limit!
    end

    it 'clears rate limit cache' do
      expect(controller).to receive(:clear_verification_rate_limit_cache)

      controller.reset_email_verification_rate_limit!
    end
  end

  describe '#get_email_verification_rate_limit_info' do
    before do
      allow(controller).to receive_messages(
        verification_period_count: 1,
        verification_daily_count: 3,
        time_until_next_verification_allowed: 240
      )
    end

    it 'returns comprehensive rate limit information' do
      info = controller.get_email_verification_rate_limit_info

      expect(info).to eq({
                           period_count: 1,
                           daily_count: 3,
                           max_per_period: 1,
                           max_daily: 5,
                           period_minutes: 5,
                           time_until_next_email: 240
                         })
    end
  end

  describe '#format_verification_time_duration' do
    it 'returns "0 seconds" for zero or negative values' do
      expect(controller.send(:format_verification_time_duration, 0)).to eq('0 seconds')
      expect(controller.send(:format_verification_time_duration, -10)).to eq('0 seconds')
    end

    context 'for seconds (< 60)' do
      it 'returns singular form for 1 second' do
        expect(controller.send(:format_verification_time_duration, 1)).to eq('1 second')
      end

      it 'returns plural form for multiple seconds' do
        expect(controller.send(:format_verification_time_duration, 30)).to eq('30 seconds')
        expect(controller.send(:format_verification_time_duration, 59)).to eq('59 seconds')
      end
    end

    context 'for minutes (>= 60, < 3600)' do
      it 'returns singular form for 1 minute' do
        expect(controller.send(:format_verification_time_duration, 60)).to eq('1 minute')
      end

      it 'returns plural form for multiple minutes' do
        expect(controller.send(:format_verification_time_duration, 120)).to eq('2 minutes')
        expect(controller.send(:format_verification_time_duration, 3599)).to eq('60 minutes')
      end

      it 'rounds up to avoid "0 minutes"' do
        expect(controller.send(:format_verification_time_duration, 61)).to eq('2 minutes')
        expect(controller.send(:format_verification_time_duration, 119)).to eq('2 minutes')
      end
    end

    context 'for hours (>= 3600)' do
      it 'returns singular form for 1 hour' do
        expect(controller.send(:format_verification_time_duration, 3600)).to eq('1 hour')
      end

      it 'returns plural form for multiple hours' do
        expect(controller.send(:format_verification_time_duration, 7200)).to eq('2 hours')
        expect(controller.send(:format_verification_time_duration, 86_400)).to eq('24 hours')
      end

      it 'rounds up to avoid fractional hours' do
        expect(controller.send(:format_verification_time_duration, 3601)).to eq('2 hours')
        expect(controller.send(:format_verification_time_duration, 7199)).to eq('2 hours')
      end
    end
  end

  describe '#time_until_next_verification_allowed' do
    it 'returns the larger of period and daily TTLs' do
      allow(redis_client).to receive(:ttl).and_return(120).with('test-uuid-123:email_verification:period')
      allow(redis_client).to receive(:ttl).and_return(300).with('test-uuid-123:email_verification:daily')

      expect(controller.send(:time_until_next_verification_allowed)).to eq(300)
    end

    it 'returns period TTL when it is larger' do
      allow(redis_client).to receive(:ttl).and_return(400).with('test-uuid-123:email_verification:period')
      allow(redis_client).to receive(:ttl).and_return(200).with('test-uuid-123:email_verification:daily')

      expect(controller.send(:time_until_next_verification_allowed)).to eq(400)
    end

    it 'returns 0 when both TTLs are negative' do
      allow(redis_client).to receive(:ttl).and_return(-1).with('test-uuid-123:email_verification:period')
      allow(redis_client).to receive(:ttl).and_return(-2).with('test-uuid-123:email_verification:daily')

      expect(controller.send(:time_until_next_verification_allowed)).to eq(0)
    end
  end

  describe '#build_verification_rate_limit_message' do
    before do
      allow(controller).to receive_messages(
        time_until_next_verification_allowed: 300,
        format_verification_time_duration: '5 minutes'
      )
      allow(controller).to receive(:format_verification_time_duration).with(300).and_return('5 minutes')
    end

    it 'builds proper error message' do
      message = controller.send(:build_verification_rate_limit_message)

      expect(message).to eq('Verification email limit reached. Wait 5 minutes to try again.')
    end
  end

  describe '#verification_period_key' do
    it 'generates correct Redis key for period' do
      expect(controller.send(:verification_period_key)).to eq('test-uuid-123:email_verification:period')
    end
  end

  describe '#verification_daily_key' do
    it 'generates correct Redis key for daily' do
      expect(controller.send(:verification_daily_key)).to eq('test-uuid-123:email_verification:daily')
    end
  end

  describe '#verification_redis' do
    it 'returns memoized Redis client with correct namespace' do
      result1 = controller.send(:verification_redis)
      result2 = controller.send(:verification_redis)

      expect(result1).to eq(result2)
    end
  end

  describe '#verification_period_count' do
    it 'caches Redis get result' do
      allow(redis_client).to receive(:get).with('test-uuid-123:email_verification:period').and_return('3')

      expect(controller.send(:verification_period_count)).to eq(3)
      expect(controller.send(:verification_period_count)).to eq(3)
      expect(redis_client).to have_received(:get).once
    end

    it 'converts string result to integer' do
      allow(redis_client).to receive(:get).and_return('5')

      expect(controller.send(:verification_period_count)).to eq(5)
    end

    it 'handles nil result from Redis' do
      allow(redis_client).to receive(:get).and_return(nil)

      expect(controller.send(:verification_period_count)).to eq(0)
    end
  end

  describe '#verification_daily_count' do
    it 'caches Redis get result' do
      allow(redis_client).to receive(:get).with('test-uuid-123:email_verification:daily').and_return('2')

      expect(controller.send(:verification_daily_count)).to eq(2)
      expect(controller.send(:verification_daily_count)).to eq(2)
      expect(redis_client).to have_received(:get).once
    end
  end

  describe '#clear_verification_rate_limit_cache' do
    it 'clears cached instance variables' do
      # Set some cached values
      controller.instance_variable_set(:@verification_period_count, 5)
      controller.instance_variable_set(:@verification_daily_count, 10)

      controller.send(:clear_verification_rate_limit_cache)

      expect(controller.instance_variable_get(:@verification_period_count)).to be_nil
      expect(controller.instance_variable_get(:@verification_daily_count)).to be_nil
    end
  end

  describe '#log_email_verification_rate_limit_denial' do
    let(:rate_limit_info) do
      {
        period_count: 1,
        daily_count: 3,
        max_per_period: 1,
        max_daily: 5
      }
    end

    it 'logs warning with proper context' do
      controller.send(:log_email_verification_rate_limit_denial, rate_limit_info)

      expect(Rails.logger).to have_received(:warn).with(
        'Email verification rate limit exceeded',
        {
          user_uuid: 'test-uuid-123',
          rate_limit_info:,
          controller: test_controller_class.name
        }
      )
    end

    it 'sends StatsD metric' do
      controller.send(:log_email_verification_rate_limit_denial, rate_limit_info)

      expect(StatsD).to have_received(:increment).with(
        'api.email_verification.rate_limit_exceeded',
        tags: {
          'user_uuid' => 'test-uuid-123',
          'controller' => test_controller_class.name
        }
      )
    end
  end
end
