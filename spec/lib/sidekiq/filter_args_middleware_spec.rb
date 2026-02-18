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

    it 'redacts string args that look like email (contain @) so exception logs do not contain PII' do
      job = {
        'class' => 'VANotifyEmailJob',
        'args' => ['user@va.gov', 'template_id', { 'first_name' => 'Jane' }, {}]
      }
      middleware.call(worker, job, queue) {}

      expect(job['args'][0]).to eq('[REDACTED]')
      expect(job['args'][1]).to eq('template_id')
      expect(job['args'][2]).to eq({}) # first_name stripped from hash
      expect(job['args'][0]).not_to include('user@va.gov')
    end

    it 'leaves args filtered when the block raises so error handlers do not log PII' do
      job = { 'class' => 'SomeJob', 'args' => [{ email: 'pii@va.gov', id: 1 }] }
      expect { middleware.call(worker, job, queue) { raise 'boom' } }.to raise_error('boom')
      expect(job['args'][0]).to eq({ id: 1 })
    end

    it 'FilterArgsMiddleware.filter_job! filters a job hash in place for use in error handlers' do
      job = {
        'class' => 'DebtManagementCenter::VANotifyEmailJob',
        'args' => ['pii@va.gov', 'template_id', { 'first_name' => 'Jane' }, {}]
      }
      Sidekiq::FilterArgsMiddleware.filter_job!(job)
      expect(job['args'][0]).to eq('[REDACTED]')
      expect(job['args'][2]).to eq({})
      expect(job.inspect).not_to include('pii@va.gov', 'Jane')
    end

    it 'ensures hash args never contain email or first_name so logging job never logs those PII keys' do
      # Middleware strips :email and :first_name from any Hash in args (e.g. user_pii, personalisation)
      pii_email = 'never-log-me@va.gov'
      pii_first_name = 'NeverLogMe'
      job = {
        'class' => 'SomeJob',
        'jid' => 'abc123',
        'args' => [
          { 'email' => pii_email, 'first_name' => pii_first_name, 'id' => 1 }
        ]
      }
      middleware.call(worker, job, queue) {}

      # Simulate what gets logged when job is inspected (e.g. death handler, SemanticLogging)
      logged_content = job.inspect + job['args'].inspect

      expect(logged_content).not_to include(pii_email), 'email must not appear in job after middleware'
      expect(logged_content).not_to include(pii_first_name), 'first_name must not appear in job after middleware'
    end
  end
end
