# frozen_string_literal: true

require 'rails_helper'
require 'zero_silent_failures/monitor'
require 'logging/monitor'
require 'logging/sidekiq'

RSpec.describe Logging::Sidekiq do
  let(:service) { 'test-application' }
  let(:monitor) { described_class.new(service) }
  let(:call_location) { double('Location', base_label: 'method_name', path: '/path/to/file.rb', lineno: 42) }
  let(:metric) { 'api.monitor.sidekiq' }
  let(:user_account_uuid) { '123-test-uuid' }
  let(:benefits_intake_uuid) { '123-test-uuid' }
  let(:additional_context) { { file: 'foobar.pdf', attachments: ['file.txt', 'file2.txt'] } }
  let(:claim) do
    FactoryBot.create(
      :pensions_module_pension_claim,
      form: {
        veteranFullName: {
          first: 'Test',
          last: 'User'
        },
        email: 'foo@foo.com',
        veteranDateOfBirth: '1989-12-13',
        veteranSocialSecurityNumber: '111223333',
        veteranAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        },
        statementOfTruthCertified: true,
        statementOfTruthSignature: 'Test User'
      }.to_json
    )
  end
  let(:payload) do
    {
      statsd: 'OVERRIDE',
      user_account_uuid: user_account_uuid,
      claim_id: claim&.id,
      benefits_intake_uuid: benefits_intake_uuid,
      confirmation_number: claim&.confirmation_number,
      additional_context: additional_context,
      function: call_location.base_label,
      file: call_location.path,
      line: call_location.lineno
    }
  end

  context 'with a call location provided' do
    describe '#track_claim_submission' do
      it 'logs a request with call location' do
        payload[:statsd] = 'api.monitor.sidekiq'

        expect(StatsD).to receive(:increment).with('api.monitor.sidekiq')
        expect(Rails.logger).to receive(:info).with('Lighthouse::Job submission to LH attempted', payload)

        monitor.track_claim_submission('Lighthouse::Job submission to LH attempted', metric, claim,
                                       benefits_intake_uuid, user_account_uuid, additional_context, call_location:)
      end
    end

    describe '#track_claim_submission_warn' do
      it 'logs a request with call location' do
        payload[:statsd] = 'api.monitor.sidekiq'

        expect(StatsD).to receive(:increment).with('api.monitor.sidekiq')
        expect(Rails.logger).to receive(:warn).with('Lighthouse::Job submission to LH failure', payload)

        monitor.track_claim_submission_warn('Lighthouse::Job submission to LH failure', metric, claim,
                                            benefits_intake_uuid, user_account_uuid, additional_context, call_location:)
      end
    end

    describe '#track_claim_submission_error' do
      it 'logs a request with call location' do
        payload[:statsd] = 'api.monitor.sidekiq'

        expect(StatsD).to receive(:increment).with('api.monitor.sidekiq')
        expect(Rails.logger).to receive(:error).with('Lighthouse::Job submission to LH exhausted!', payload)

        monitor.track_claim_submission_error('Lighthouse::Job submission to LH exhausted!', metric, claim,
                                             benefits_intake_uuid, user_account_uuid,
                                             additional_context, call_location:)
      end
    end
  end
end
