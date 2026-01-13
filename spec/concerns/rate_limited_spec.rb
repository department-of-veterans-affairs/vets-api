# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RateLimited, type: :controller do
  let(:test_controller_class) do
    Class.new(ApplicationController) do
      include RateLimited

      rate_limit :test_action, per_period: 2, period: 5.minutes, daily_limit: 10
      rate_limit :other_action, per_period: 1, period: 1.minute, daily_limit: 5,
                                redis_namespace: 'custom_namespace'

      attr_reader :current_user

      def test_action
        enforce_rate_limit!(:test_action)
        increment_rate_limit!(:test_action)
        render json: { success: true }
      end

      def other_action
        enforce_rate_limit!(:other_action)
        increment_rate_limit!(:other_action)
        render json: { success: true }
      end

      def unconfigured_action
        enforce_rate_limit!(:unconfigured)
      end
    end
  end

  let(:controller) { test_controller_class.new }
  let(:user) { create(:user, :loa3) }
  let(:redis) { Redis.new }

  before do
    controller.instance_variable_set(:@current_user, user)
    allow($redis).to receive(:get).and_call_original
    allow($redis).to receive(:set).and_call_original
    allow($redis).to receive(:incr).and_call_original
    allow($redis).to receive(:expire).and_call_original
    allow($redis).to receive(:del).and_call_original
    allow($redis).to receive(:ttl).and_call_original
    allow($redis).to receive(:multi).and_yield($redis).and_call_original

    # Clear any existing rate limit data
    controller.reset_rate_limit!(:test_action)
    controller.reset_rate_limit!(:other_action)
  end

  describe 'class methods' do
    describe '.rate_limit' do
      it 'configures rate limiting for an action' do
        config = test_controller_class.rate_limit_configs[:test_action]

        expect(config).to include(
          per_period: 2,
          period: 5.minutes,
          daily_limit: 10,
          daily_period: 24.hours
        )
      end

      it 'generates default redis namespace from class name' do
        config = test_controller_class.rate_limit_configs[:test_action]

        # Anonymous classes get the "anonymous" fallback namespace
        expect(config[:redis_namespace]).to eq('anonymous_rate_limit')
      end

      it 'accepts custom redis namespace' do
        config = test_controller_class.rate_limit_configs[:other_action]

        expect(config[:redis_namespace]).to eq('custom_namespace')
      end
    end
  end

  describe 'instance methods' do
    describe '#enforce_rate_limit!' do
      context 'when no rate limit is configured' do
        it 'raises ArgumentError' do
          expect { controller.unconfigured_action }.to raise_error(ArgumentError, /No rate limit configured/)
        end
      end

      context 'when rate limit is not exceeded' do
        it 'allows the request to proceed' do
          allow(controller).to receive(:rate_limit_exceeded?).with(:test_action).and_return(false)

          expect(controller).not_to receive(:render)
          controller.send(:enforce_rate_limit!, :test_action)
        end
      end

      context 'when rate limit is exceeded' do
        before do
          allow(controller).to receive(:rate_limit_exceeded?).with(:test_action).and_return(true)
          allow(controller).to receive(:get_rate_limit_info).with(:test_action).and_return({
                                                                                             period_count: 3,
                                                                                             daily_count: 5,
                                                                                             max_per_period: 2,
                                                                                             max_daily: 10,
                                                                                             period_seconds: 300,
                                                                                             time_until_reset: 120
                                                                                           })
        end

        it 'renders rate limit error response' do
          expect(controller).to receive(:render).with(
            json: hash_including(
              errors: array_including(
                hash_including(
                  title: 'Rate Limit Exceeded',
                  code: 'RATE_LIMIT_EXCEEDED',
                  status: '429'
                )
              )
            ),
            status: :too_many_requests
          )

          controller.send(:enforce_rate_limit!, :test_action)
        end

        it 'logs rate limit denial' do
          expect(Rails.logger).to receive(:warn).with('Rate limit exceeded', hash_including(
                                                                               user_uuid: user.uuid,
                                                                               action: :test_action
                                                                             ))

          expect(StatsD).to receive(:increment).with('api.rate_limit_exceeded', hash_including(
                                                                                  tags: hash_including(
                                                                                    'user_uuid' => user.uuid,
                                                                                    'action' => 'test_action'
                                                                                  )
                                                                                ))

          allow(controller).to receive(:render)
          controller.send(:enforce_rate_limit!, :test_action)
        end
      end
    end

    describe '#rate_limit_exceeded?' do
      it 'returns false when neither limit is exceeded' do
        allow(controller).to receive(:period_count).with(:test_action).and_return(1)
        allow(controller).to receive(:daily_count).with(:test_action).and_return(5)

        expect(controller.rate_limit_exceeded?(:test_action)).to be false
      end

      it 'returns true when period limit is exceeded' do
        allow(controller).to receive(:period_count).with(:test_action).and_return(3)
        allow(controller).to receive(:daily_count).with(:test_action).and_return(5)

        expect(controller.rate_limit_exceeded?(:test_action)).to be true
      end

      it 'returns true when daily limit is exceeded' do
        allow(controller).to receive(:period_count).with(:test_action).and_return(1)
        allow(controller).to receive(:daily_count).with(:test_action).and_return(11)

        expect(controller.rate_limit_exceeded?(:test_action)).to be true
      end

      it 'returns false when no config exists' do
        expect(controller.rate_limit_exceeded?(:nonexistent)).to be false
      end
    end

    describe '#increment_rate_limit!' do
      it 'increments both period and daily counters' do
        redis_client = instance_double(Redis::Namespace)
        allow(controller).to receive(:redis).with(:test_action).and_return(redis_client)

        expect(redis_client).to receive(:multi).twice.and_yield(redis_client)
        expect(redis_client).to receive(:incr).with(/period$/)
        expect(redis_client).to receive(:expire).with(/period$/, 300)
        expect(redis_client).to receive(:incr).with(/daily$/)
        expect(redis_client).to receive(:expire).with(/daily$/, 86_400)

        controller.increment_rate_limit!(:test_action)
      end

      it 'clears cached counts' do
        allow(controller).to receive(:redis).and_return(instance_double(Redis::Namespace, multi: nil))

        controller.instance_variable_set(:@period_count_test_action, 5)
        controller.instance_variable_set(:@daily_count_test_action, 10)

        controller.increment_rate_limit!(:test_action)

        expect(controller.instance_variable_get(:@period_count_test_action)).to be_nil
        expect(controller.instance_variable_get(:@daily_count_test_action)).to be_nil
      end
    end

    describe '#reset_rate_limit!' do
      it 'deletes Redis keys and clears cache' do
        redis_client = instance_double(Redis::Namespace)
        allow(controller).to receive(:redis).with(:test_action).and_return(redis_client)

        expect(redis_client).to receive(:del).with(/period$/, /daily$/)

        controller.instance_variable_set(:@period_count_test_action, 5)
        controller.instance_variable_set(:@daily_count_test_action, 10)

        controller.reset_rate_limit!(:test_action)

        expect(controller.instance_variable_get(:@period_count_test_action)).to be_nil
        expect(controller.instance_variable_get(:@daily_count_test_action)).to be_nil
      end
    end

    describe '#get_rate_limit_info' do
      it 'returns comprehensive rate limit information' do
        allow(controller).to receive(:period_count).with(:test_action).and_return(1)
        allow(controller).to receive(:daily_count).with(:test_action).and_return(3)
        allow(controller).to receive(:time_until_next_allowed_seconds).with(:test_action).and_return(120)

        info = controller.get_rate_limit_info(:test_action)

        expect(info).to eq({
                             period_count: 1,
                             daily_count: 3,
                             max_per_period: 2,
                             max_daily: 10,
                             period_seconds: 300,
                             time_until_reset: 120
                           })
      end

      it 'returns empty hash for unconfigured action' do
        expect(controller.get_rate_limit_info(:nonexistent)).to eq({})
      end
    end

    describe '#check_and_increment_rate_limit!' do
      it 'returns true and increments when limit not exceeded' do
        allow(controller).to receive(:rate_limit_exceeded?).with(:test_action).and_return(false)
        expect(controller).to receive(:increment_rate_limit!).with(:test_action)

        result = controller.check_and_increment_rate_limit!(:test_action)
        expect(result).to be true
      end

      it 'returns false and does not increment when limit exceeded' do
        allow(controller).to receive(:rate_limit_exceeded?).with(:test_action).and_return(true)
        expect(controller).not_to receive(:increment_rate_limit!)

        result = controller.check_and_increment_rate_limit!(:test_action)
        expect(result).to be false
      end
    end
  end

  describe '#period_count and #daily_count' do
    it 'caches Redis results' do
      redis_client = instance_double(Redis::Namespace)
      allow(controller).to receive(:redis).with(:test_action).and_return(redis_client)

      expect(redis_client).to receive(:get).with(/period$/).once.and_return('3')

      # First call should hit Redis
      count1 = controller.send(:period_count, :test_action)
      # Second call should use cache
      count2 = controller.send(:period_count, :test_action)

      expect(count1).to eq(3)
      expect(count2).to eq(3)
    end
  end

  describe '#time_until_next_allowed_seconds' do
    it 'returns the maximum TTL from period and daily keys' do
      redis_client = instance_double(Redis::Namespace)
      allow(controller).to receive(:redis).with(:test_action).and_return(redis_client)

      allow(redis_client).to receive(:ttl).with(/period$/).and_return(120)
      allow(redis_client).to receive(:ttl).with(/daily$/).and_return(300)

      result = controller.send(:time_until_next_allowed_seconds, :test_action)
      expect(result).to eq(300)
    end
  end

  describe '#format_time_duration' do
    it 'formats seconds correctly' do
      expect(controller.send(:format_time_duration, 0)).to eq('0 seconds')
      expect(controller.send(:format_time_duration, 1)).to eq('1 second')
      expect(controller.send(:format_time_duration, 30)).to eq('30 seconds')
      expect(controller.send(:format_time_duration, 60)).to eq('1 minute')
      expect(controller.send(:format_time_duration, 120)).to eq('2 minutes')
      expect(controller.send(:format_time_duration, 3600)).to eq('1 hour')
      expect(controller.send(:format_time_duration, 7200)).to eq('2 hours')
    end
  end

  describe '#period_key and #daily_key' do
    it 'generates correct Redis keys' do
      period_key = controller.send(:period_key, :test_action)
      daily_key = controller.send(:daily_key, :test_action)

      expect(period_key).to eq("#{user.uuid}:test_action:period")
      expect(daily_key).to eq("#{user.uuid}:test_action:daily")
    end
  end

  describe '#redis' do
    it 'creates namespaced Redis client' do
      redis_client = controller.send(:redis, :test_action)

      expect(redis_client).to be_a(Redis::Namespace)
      expect(redis_client.namespace).to match(/_rate_limit$/)
    end

    it 'uses custom namespace when configured' do
      redis_client = controller.send(:redis, :other_action)

      expect(redis_client).to be_a(Redis::Namespace)
      expect(redis_client.namespace).to eq('custom_namespace')
    end

    it 'caches Redis clients per action' do
      client1 = controller.send(:redis, :test_action)
      client2 = controller.send(:redis, :test_action)

      expect(client1).to be(client2)
    end
  end

  describe 'error message building' do
    describe '#build_rate_limit_error_message' do
      it 'builds human-readable error message' do
        allow(controller).to receive(:time_until_next_allowed_seconds).with(:test_action).and_return(120)

        message = controller.send(:build_rate_limit_error_message, :test_action)
        expect(message).to include('exceeded the maximum number of requests')
        expect(message).to include('2 minutes')
      end
    end

    describe '#build_rate_limit_meta' do
      it 'builds metadata for error response' do
        config = { per_period: 2, period: 5.minutes, daily_limit: 10 }
        allow(controller).to receive(:time_until_next_allowed_seconds).with(:test_action).and_return(120)

        meta = controller.send(:build_rate_limit_meta, :test_action, config)

        expect(meta).to eq({
                             retry_after: 120,
                             per_period_limit: 2,
                             period_seconds: 300,
                             daily_limit: 10
                           })
      end
    end
  end

  describe 'integration test' do
    it 'properly tracks rate limit state through multiple calls' do
      # Verify initial state - no limits exceeded
      expect(controller.rate_limit_exceeded?(:test_action)).to be false

      # Make requests up to the period limit
      2.times do
        controller.increment_rate_limit!(:test_action)
      end

      # Should now exceed period limit
      expect(controller.rate_limit_exceeded?(:test_action)).to be true

      # Reset should clear the limits
      controller.reset_rate_limit!(:test_action)
      expect(controller.rate_limit_exceeded?(:test_action)).to be false
    end
  end
end
