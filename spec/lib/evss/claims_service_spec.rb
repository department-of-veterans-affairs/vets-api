# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

describe EVSS::ClaimsService do
  let(:current_user) { FactoryGirl.create(:loa3_user) }
  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  let(:claims_service) { described_class.new(auth_headers) }

  subject { claims_service }

  describe '#benchmark_request' do
    let(:redis) { Redis.current }
    let(:benchmark_key) { EVSS::ClaimsService::BENCHMARK_KEY }

    def average
      BigDecimal.new(redis.get(benchmark_key))
    end

    def count
      redis.get("#{benchmark_key}.count").to_i
    end

    subject do
      claims_service.send(:benchmark_request) do
        123
      end
    end

    before do
      time = Time.utc(2000)
      num_calls = 0

      expect(Time).to receive(:current).twice do
        num_calls += 1
        time + num_calls.seconds
      end
    end

    context 'with an existing average' do
      before do
        redis.set(benchmark_key, BigDecimal.new('0.5'))
        redis.set("#{benchmark_key}.count", 1)
      end

      it 'should set the average and count correctly' do
        subject

        expect(average).to eq(0.75)
        expect(count).to eq(2)
      end
    end

    context 'without an existing average' do
      it 'should set the average and count correctly' do
        subject

        expect(average).to eq(1)
        expect(count).to eq(1)
      end
    end

    it 'should return the blocks return value' do
      expect(subject).to eq(123)
    end

    it 'should log the values to sentry' do
      expect(claims_service).to receive(:log_message_to_sentry).with(
        'Average EVSS request in seconds',
        :info,
        { average: BigDecimal.new(1), count: 1 },
        backend_service: :evss
      )

      subject
    end
  end

  context 'with headers' do
    let(:evss_id) { 189_625 }

    it 'should get claims' do
      VCR.use_cassette('evss/claims/claims') do
        response = subject.all_claims
        expect(response).to be_success
      end
    end

    it 'should post a 5103 waiver' do
      VCR.use_cassette('evss/claims/set_5103_waiver') do
        response = subject.request_decision(evss_id)
        expect(response).to be_success
      end
    end
  end
end
