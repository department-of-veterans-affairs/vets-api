# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/filter_args_middleware'

describe Sidekiq::FilterArgsMiddleware do
  let(:middleware) { described_class.new }
  let(:worker) { double('worker') }
  let(:queue) { 'default' }

  def apply_middleware(job)
    middleware.call(worker, job, queue) {}
    job
  end

  describe '#call' do
    it 'yields to the block' do
      job = { 'class' => 'SomeJob', 'args' => [1, 2] }
      yielded = false
      middleware.call(worker, job, queue) { yielded = true }
      expect(yielded).to be true
    end

    describe 'only filters args for job classes in PII_REDACT_JOB_CLASSES' do
      it 'filters args when job class is in PII_REDACT_JOB_CLASSES' do
        described_class::PII_REDACT_JOB_CLASSES.each do |job_class|
          job = {
            'class' => job_class,
            'args' => [{ 'email' => 'pii@va.gov', 'first_name' => 'Jane', id: 123 }]
          }
          apply_middleware(job)
          expect(job['args'][0]).to eq({ id: 123 }), "expected #{job_class} args to be filtered"
        end
      end

      it 'does not filter args when job class is not in PII_REDACT_JOB_CLASSES' do
        job = {
          'class' => 'SomeOtherJob',
          'args' => [{ 'email' => 'pii@va.gov', 'first_name' => 'Jane', id: 123 }]
        }
        apply_middleware(job)
        expect(job['args'][0]).to eq({ 'email' => 'pii@va.gov', 'first_name' => 'Jane', id: 123 })
      end

      it 'does not filter args for a similarly named class not in the allowlist' do
        job = {
          'class' => 'VANotifyEmailJob',
          'args' => [{ 'email' => 'pii@va.gov', 'first_name' => 'Jane', id: 123 }]
        }
        apply_middleware(job)
        expect(job['args'][0]).to include('email' => 'pii@va.gov', 'first_name' => 'Jane')
      end
    end

    it 'filters :email and :first_name from hash args (symbol or string keys) for allowlisted classes' do
      [
        [{ email: 'pii@va.gov', first_name: 'Jane', id: 123 }],
        [{ 'email' => 'pii@va.gov', 'first_name' => 'Jane', 'id' => 123 }]
      ].each do |args|
        job = { 'class' => 'DebtsApi::V0::Form5655::SendConfirmationEmailJob', 'args' => args }
        apply_middleware(job)
        expect(job['args'][0]).to eq({ id: 123 })
      end
    end

    it 'leaves non-hash args unchanged' do
      job = { 'class' => 'SomeJob', 'args' => ['template_123', 42, true, nil] }
      apply_middleware(job)
      expect(job['args']).to eq(['template_123', 42, true, nil])
    end

    it 'redacts string args that look like email (contain @) so exception logs do not contain PII' do
      job = {
        'class' => 'DebtManagementCenter::VANotifyEmailJob',
        'args' => ['user@va.gov', 'template_id', { 'first_name' => 'Jane' }, {}]
      }
      apply_middleware(job)

      expect(job['args'][0]).to eq('[REDACTED]')
      expect(job['args'][1]).to eq('template_id')
      expect(job['args'][2]).to eq({})
      expect(job['args'][0]).not_to include('user@va.gov')
    end

    it 'leaves args filtered when the block raises so error handlers do not log PII' do
      job = { 'class' => 'DebtsApi::V0::Form5655::SendConfirmationEmailJob', 'args' => [{ email: 'pii@va.gov', id: 1 }] }
      expect { middleware.call(worker, job, queue) { raise 'boom' } }.to raise_error('boom')
      expect(job['args'][0]).to eq({ id: 1 })
    end

    it 'FilterArgsMiddleware.filter_job! filters a job hash in place for use in error handlers' do
      job = {
        'class' => 'DebtManagementCenter::VANotifyEmailJob',
        'args' => ['pii@va.gov', 'template_id', { 'first_name' => 'Jane' }, {}]
      }
      described_class.filter_job!(job)
      expect(job['args'][0]).to eq('[REDACTED]')
      expect(job['args'][2]).to eq({})
      expect(job.inspect).not_to include('pii@va.gov', 'Jane')
    end

    it 'ensures hash args never contain email or first_name so logging job never logs those PII keys' do
      pii_email = 'never-log-me@va.gov'
      pii_first_name = 'NeverLogMe'
      job = {
        'class' => 'DebtsApi::V0::Form5655::SendConfirmationEmailJob',
        'jid' => 'abc123',
        'args' => [{ 'email' => pii_email, 'first_name' => pii_first_name, 'id' => 1 }]
      }
      apply_middleware(job)
      logged_content = job.inspect + job['args'].inspect

      expect(logged_content).not_to include(pii_email), 'email must not appear in job after middleware'
      expect(logged_content).not_to include(pii_first_name), 'first_name must not appear in job after middleware'
    end
  end
end
