# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/filter_args_middleware'

describe Sidekiq::FilterArgsMiddleware do
  let(:middleware) { described_class.new }
  let(:worker) { double('worker') }
  let(:queue) { 'default' }

  describe '#call' do
    it 'yields to the block' do
      job = { 'class' => 'SomeJob', 'args' => [1, 2] }
      yielded = false
      middleware.call(worker, job, queue) { yielded = true }
      expect(yielded).to be true
    end

    it 'filters :email and :first_name from hash args' do
      job = {
        'class' => 'SomeJob',
        'args' => [{ email: 'pii@va.gov', first_name: 'Jane', id: 123 }]
      }
      args_during_yield = nil
      middleware.call(worker, job, queue) { args_during_yield = job['args'].map(&:dup) }
      expect(args_during_yield[0]).to eq({ id: 123 })
      expect(job['args'][0]).to eq({ email: 'pii@va.gov', first_name: 'Jane', id: 123 }) # restored
    end

    it 'replaces string args containing "email" with [FILTERED]' do
      job = { 'class' => 'SomeJob', 'args' => ['user_email: pii@va.gov'] }
      args_during_yield = nil
      middleware.call(worker, job, queue) { args_during_yield = job['args'].dup }
      expect(args_during_yield[0]).to eq('[FILTERED]')
      expect(job['args'][0]).to eq('user_email: pii@va.gov') # restored
    end

    it 'replaces string args containing "first_name" with [FILTERED]' do
      job = { 'class' => 'SomeJob', 'args' => ['first_name: Jane'] }
      args_during_yield = nil
      middleware.call(worker, job, queue) { args_during_yield = job['args'].dup }
      expect(args_during_yield[0]).to eq('[FILTERED]')
      expect(job['args'][0]).to eq('first_name: Jane') # restored
    end

    it 'leaves string args without sensitive substrings unchanged' do
      job = { 'class' => 'SomeJob', 'args' => ['template_123', 'other_data'] }
      middleware.call(worker, job, queue) {}
      expect(job['args']).to eq(['template_123', 'other_data'])
    end

    it 'leaves non-hash, non-string args unchanged' do
      job = { 'class' => 'SomeJob', 'args' => [42, true, nil] }
      middleware.call(worker, job, queue) {}
      expect(job['args']).to eq([42, true, nil])
    end

    it 'restores original args after the block runs' do
      original_args = [{ email: 'pii@va.gov', id: 1 }]
      job = { 'class' => 'SomeJob', 'args' => Marshal.load(Marshal.dump(original_args)) }
      middleware.call(worker, job, queue) {}
      expect(job['args']).to eq(original_args)
    end

    it 'restores original args when the block raises' do
      original_args = [{ email: 'pii@va.gov' }]
      job = { 'class' => 'SomeJob', 'args' => Marshal.load(Marshal.dump(original_args)) }
      expect { middleware.call(worker, job, queue) { raise 'boom' } }.to raise_error('boom')
      expect(job['args']).to eq(original_args)
    end

    it 'logs filtered args without PII' do
      job = { 'class' => 'SomeJob', 'args' => [{ email: 'pii@va.gov' }] }
      expect(Rails.logger).to receive(:info) do |msg|
        expect(msg).to include('MIDDLEWARE - Filtered args:')
        expect(msg).not_to include('pii@va.gov')
      end
      middleware.call(worker, job, queue) {}
    end
  end
end
