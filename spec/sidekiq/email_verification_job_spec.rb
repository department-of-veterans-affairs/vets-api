# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe EmailVerificationJob, type: :job do
  subject { described_class }

  let(:template_type) { 'initial_verification' }
  let(:email_address) { 'veteran@example.com' }
  let(:personalisation) { { 'verification_link' => 'https://va.gov/verify/123', 'first_name' => 'John', 'email_address' => email_address } }

  before do
    Sidekiq::Testing.fake!
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(true)
      end

      it 'logs email verification and increments success metric' do
        subject.new.perform(template_type, email_address, personalisation)

        expect(Rails.logger).to have_received(:info).with(
          'Email verification sent (logging only - not actually sent)',
          hash_including(template_type:)
        )
        expect(StatsD).to have_received(:increment).with('api.vanotify.email_verification.success')
      end

      # Test all template types in one spec
      %w[initial_verification annual_verification email_change_verification verification_success].each do |type|
        it "handles #{type} template type" do
          expect { subject.new.perform(type, email_address, personalisation) }.not_to raise_error
        end
      end

      it 'raises ArgumentError for unknown template type' do
        expect do
          subject.new.perform('unknown_type', email_address, personalisation)
        end.to raise_error(ArgumentError, 'Unknown template type')
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(false)
      end

      it 'returns early without logging or metrics' do
        subject.new.perform(template_type, email_address, personalisation)

        expect(Rails.logger).not_to have_received(:info)
        expect(StatsD).not_to have_received(:increment)
      end
    end
  end

  describe 'sidekiq configuration' do
    it 'is configured with retry: 5' do
      expect(subject.sidekiq_options['retry']).to eq(5)
    end

    it 'enqueues the job' do
      expect do
        subject.perform_async('initial_verification', email_address, personalisation)
      end.to change(subject.jobs, :size).by(1)
    end
  end

  describe 'error handling' do
    before do
      allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(true)
    end

    it 'handles general errors with failure metrics and logging' do
      allow_any_instance_of(described_class).to receive(:get_template_id).and_raise(StandardError, 'Service error')

      expect do
        subject.new.perform(template_type, email_address, personalisation)
      end.to raise_error(StandardError, 'Service error')

      expect(StatsD).to have_received(:increment).with('api.vanotify.email_verification.failure')
      expect(Rails.logger).to have_received(:error).with('EmailVerificationJob failed', {
                                                           error: 'Service error', template_type:
                                                         })
    end

    it 'does not increment failure metrics for ArgumentError' do
      expect do
        subject.new.perform('unknown_type', email_address, personalisation)
      end.to raise_error(ArgumentError)

      expect(StatsD).not_to have_received(:increment).with('api.vanotify.email_verification.failure')
      expect(Rails.logger).to have_received(:error).with('EmailVerificationJob validation failed', {
                                                           error: 'Unknown template type',
                                                           template_type: 'unknown_type'
                                                         })
    end
  end

  describe 'retries exhausted' do
    it 'logs exhaustion with proper context' do
      # Simulate sidekiq_retries_exhausted callback
      msg = {
        'jid' => 'test_job_id',
        'class' => 'EmailVerificationJob',
        'error_class' => 'StandardError',
        'error_message' => 'Connection failed',
        'args' => [template_type, email_address, personalisation]
      }

      described_class.sidekiq_retries_exhausted_block.call(msg, nil)

      expect(Rails.logger).to have_received(:error).with(
        'EmailVerificationJob retries exhausted',
        hash_including(
          job_id: 'test_job_id',
          error_class: 'StandardError',
          error_message: 'Connection failed',
          template_type:
        )
      )
      expect(StatsD).to have_received(:increment).with('api.vanotify.email_verification.retries_exhausted')
    end
  end

  describe '#validate_personalisation!' do
    let(:job_instance) { subject.new }

    context 'validates required fields per template type' do
      it 'requires verification_link, first_name, email_address for verification templates' do
        %w[initial_verification annual_verification email_change_verification].each do |type|
          incomplete_personalisation = { 'first_name' => 'John' } # missing verification_link and email_address

          expect do
            job_instance.send(:validate_personalisation!, type, incomplete_personalisation)
          end.to raise_error(ArgumentError, /Missing required personalisation fields/)
        end
      end

      it 'requires only first_name for verification_success' do
        valid_personalisation = { 'first_name' => 'John' }

        expect do
          job_instance.send(:validate_personalisation!, 'verification_success', valid_personalisation)
        end.not_to raise_error
      end

      it 'raises ArgumentError when personalisation is nil' do
        expect do
          job_instance.send(:validate_personalisation!, template_type, nil)
        end.to raise_error(ArgumentError, 'Personalisation cannot be nil')
      end
    end
  end

  describe '#get_template_id' do
    let(:job_instance) { subject.new }

    it 'returns correct template IDs for each type' do
      expect(job_instance.send(:get_template_id, 'initial_verification')).to eq(
        Settings.vanotify.services.va_gov.template_id.contact_email_address_confirmation_needed_email
      )
      expect(job_instance.send(:get_template_id, 'annual_verification')).to eq(
        Settings.vanotify.services.va_gov.template_id.contact_email_address_confirmation_needed_email
      )
      expect(job_instance.send(:get_template_id, 'email_change_verification')).to eq(
        Settings.vanotify.services.va_gov.template_id.contact_email_address_change_confirmation_needed_email
      )
      expect(job_instance.send(:get_template_id, 'verification_success')).to eq(
        Settings.vanotify.services.va_gov.template_id.contact_email_address_confirmed_email
      )
    end

    it 'raises ArgumentError for unknown template type' do
      expect do
        job_instance.send(:get_template_id, 'unknown')
      end.to raise_error(ArgumentError, 'Unknown template type')
    end
  end
end
