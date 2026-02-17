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

    it 'filters :email and :first_name from hash args (symbol keys)' do
      job = {
        'class' => 'SomeJob',
        'args' => [{ email: 'pii@va.gov', first_name: 'Jane', id: 123 }]
      }
      middleware.call(worker, job, queue) {}
      expect(job['args'][0]).to eq({ id: 123 })
    end

    it 'filters email and first_name from hash args (string keys, e.g. Sidekiq JSON)' do
      job = {
        'class' => 'SomeJob',
        'args' => [{ 'email' => 'pii@va.gov', 'first_name' => 'Jane', 'id' => 123 }]
      }
      middleware.call(worker, job, queue) {}
      expect(job['args'][0]).to eq({ id: 123 })
    end

    it 'leaves non-hash args unchanged' do
      job = { 'class' => 'SomeJob', 'args' => ['template_123', 42, true, nil] }
      middleware.call(worker, job, queue) {}
      expect(job['args']).to eq(['template_123', 42, true, nil])
    end

    it 'leaves args filtered when the block raises so error handlers do not log PII' do
      job = { 'class' => 'SomeJob', 'args' => [{ email: 'pii@va.gov', id: 1 }] }
      expect { middleware.call(worker, job, queue) { raise 'boom' } }.to raise_error('boom')
      expect(job['args'][0]).to eq({ id: 1 })
    end
  end
end
