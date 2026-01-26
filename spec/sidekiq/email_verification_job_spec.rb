# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'sidekiq/attr_package'

Sidekiq::Testing.fake!

RSpec.describe EmailVerificationJob, type: :job do
  subject { described_class }

  let(:template_type) { 'initial_verification' }
  let(:cache_key) { 'test_cache_key_123' }
  let(:personalisation_data) do
    {
      verification_link: 'https://va.gov/verify/123',
      first_name: 'John',
      email: 'veteran@example.com'
    }
  end
  let(:notify_client) { instance_double(VaNotify::Service) }

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(VaNotify::Service).to receive(:new).and_return(notify_client)
    allow(notify_client).to receive(:send_email)
    allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(personalisation_data)
    allow(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)
  end

  describe '#perform' do
    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(true)
      end

      it 'retrieves PII data from cache and logs email verification and increments success metric' do
        subject.new.perform(template_type, cache_key)

        expect(Sidekiq::AttrPackage).to have_received(:find).with(cache_key)
        expect(Rails.logger).to have_received(:info).with(
          'Email verification sent (logging only - not actually sent)',
          hash_including(template_type:)
        )
        expect(StatsD).to have_received(:increment).with('api.vanotify.email_verification.success')
        expect(Sidekiq::AttrPackage).to have_received(:delete).with(cache_key)
      end

      it 'raises ArgumentError when cache data is missing' do
        allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(nil)

        expect do
          subject.new.perform(template_type, cache_key)
        end.to raise_error(ArgumentError, 'Missing personalisation data in Redis')

        expect(Rails.logger).to have_received(:error).with(
          'EmailVerificationJob failed: Missing personalisation data in Redis',
          hash_including(template_type:, cache_key_present: true)
        )
      end

      %w[initial_verification annual_verification email_change_verification].each do |type|
        it "handles #{type} template type with verification templates data structure" do
          verification_data = {
            verification_link: 'https://va.gov/verify/123',
            first_name: 'John',
            email: 'veteran@example.com'
          }
          allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(verification_data)

          expect { subject.new.perform(type, cache_key) }.not_to raise_error
        end
      end

      it 'handles verification_success template type with success data structure' do
        success_data = { first_name: 'John', email: 'veteran@example.com' }
        allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(success_data)

        expect { subject.new.perform('verification_success', cache_key) }.not_to raise_error
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(false)
      end

      it 'returns early without logging or metrics' do
        subject.new.perform(template_type, cache_key)

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
        subject.perform_async(template_type, cache_key)
      end.to change(subject.jobs, :size).by(1)
    end
  end

  describe 'error handling' do
    before do
      allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(true)
    end

    it 'handles general errors with failure metrics and logging' do
      allow_any_instance_of(described_class).to receive(:build_personalisation).and_raise(StandardError,
                                                                                          'Service error')

      expect do
        subject.new.perform(template_type, cache_key)
      end.to raise_error(StandardError, 'Service error')

      expect(StatsD).to have_received(:increment).with('api.vanotify.email_verification.failure')
      expect(Rails.logger).to have_received(:error).with('EmailVerificationJob failed', {
                                                           error: 'Service error', template_type:
                                                         })
    end

    it 'does not increment failure metrics for ArgumentError' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(nil)

      expect do
        subject.new.perform(template_type, cache_key)
      end.to raise_error(ArgumentError)

      expect(StatsD).not_to have_received(:increment)
        .with('api.vanotify.email_verification.failure')
      expect(Rails.logger).to have_received(:error)
        .with(
          'EmailVerificationJob failed: Missing personalisation data in Redis', {
            template_type:,
            cache_key_present: true
          }
        )
    end

    it 'handles Sidekiq::AttrPackageError as ArgumentError (no retries)' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_raise(
        Sidekiq::AttrPackageError.new('find', 'Redis connection failed')
      )

      expect do
        subject.new.perform(template_type, cache_key)
      end.to raise_error(ArgumentError, '[Sidekiq] [AttrPackage] find error: Redis connection failed')

      expect(Rails.logger)
        .to have_received(:error)
        .with(
          'EmailVerificationJob AttrPackage error', {
            error: '[Sidekiq] [AttrPackage] find error: Redis connection failed',
            template_type:
          }
        )
      expect(StatsD).not_to have_received(:increment).with('api.vanotify.email_verification.failure')
    end
  end

  describe 'retries exhausted' do
    it 'logs exhaustion with proper context and cleans up cache' do
      # Simulate sidekiq_retries_exhausted callback with new parameter structure
      msg = {
        'jid' => 'test_job_id',
        'class' => 'EmailVerificationJob',
        'error_class' => 'StandardError',
        'error_message' => 'Connection failed',
        'args' => [template_type, cache_key]
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

  describe '#callback_options' do
    let(:job_instance) { subject.new }

    it 'returns properly structured callback options for each template type' do
      %w[initial_verification annual_verification email_change_verification verification_success].each do |type|
        options = job_instance.send(:callback_options, type)

        expect(options).to eq({
                                callback_klass: 'EmailVerificationCallback',
                                callback_metadata: {
                                  statsd_tags: {
                                    service: 'vagov-profile-email-verification',
                                    function: "#{type}_email"
                                  }
                                }
                              })
      end
    end

    it 'references a valid callback class' do
      options = job_instance.send(:callback_options, 'initial_verification')
      callback_klass = options[:callback_klass]

      expect { callback_klass.constantize }.not_to raise_error
      expect(callback_klass.constantize).to respond_to(:call)
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

  describe '#build_personalisation' do
    let(:job_instance) { subject.new }

    it 'builds correct personalisation for verification templates' do
      data = { verification_link: 'https://va.gov/verify/123', first_name: 'John', email: 'test@va.gov' }

      %w[initial_verification annual_verification email_change_verification].each do |type|
        result = job_instance.send(:build_personalisation, type, data)
        expect(result).to eq({
                               'verification_link' => 'https://va.gov/verify/123',
                               'first_name' => 'John',
                               'email_address' => 'test@va.gov'
                             })
      end
    end

    it 'builds correct personalisation for verification_success' do
      data = { first_name: 'John', email: 'test@va.gov' }
      result = job_instance.send(:build_personalisation, 'verification_success', data)

      expect(result).to eq({ 'first_name' => 'John' })
    end

    it 'raises ArgumentError for unknown template type' do
      data = { first_name: 'John' }

      expect do
        job_instance.send(:build_personalisation, 'unknown_type', data)
      end.to raise_error(ArgumentError, 'Unknown template type')
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
