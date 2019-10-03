# frozen_string_literal: true

require 'rails_helper'

describe Common::EventRateLimiter do
  context 'with the default evss 526 config' do
    let(:config) do
      {
        'namespace' => 'evss-526-submit-form-rate-limit',
        'threshold_limit' => 10,
        'threshold_ttl' => 86_400,
        'count_limit' => 30,
        'count_ttl' => 604_800
      }
    end

    subject { Common::EventRateLimiter.new(config) }

    describe '.at_limit?' do
      context 'with no events' do
        it 'returns false' do
          expect(subject).not_to be_at_limit
        end
      end

      context 'when the threshold is not exceeded (< 10 in day)' do
        before { 5.times { subject.increment } }

        it 'returns false' do
          expect(subject).not_to be_at_limit
        end
      end

      context 'when the threshold is exceeded (> 10 in day)' do
        before { 11.times { subject.increment } }

        it 'returns true' do
          expect(subject).to be_at_limit
        end
      end

      context 'when the count is not exceeded during its TTL (< 30 in a week)' do
        before do
          5.times { subject.increment }
          Timecop.travel(1.day)
          7.times { subject.increment }
          Timecop.travel(1.day)
          3.times { subject.increment }
        end

        it 'returns false' do
          expect(subject).not_to be_at_limit
        end
      end

      context 'when the count is exceeded during its TTL (> 30 in a week)' do
        before do
          5.times do
            7.times { subject.increment }
            Timecop.travel(1.day)
          end
        end

        it 'returns true' do
          expect(subject).to be_at_limit
        end
      end
    end

    describe '.increment' do
      it 'increments both threshold and count', :aggregate_failures do
        expect(subject.instance_variable_get(:@redis).get(:threshold).to_i).to eq(0)
        expect(subject.instance_variable_get(:@redis).get(:count).to_i).to eq(0)
        subject.increment
        expect(subject.instance_variable_get(:@redis).get(:threshold).to_i).to eq(1)
        expect(subject.instance_variable_get(:@redis).get(:count).to_i).to eq(1)
      end
    end

    after(:each) { Timecop.return }
  end
end
