# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'

RSpec.describe VANotify::V2::QueueUserAccountJob, type: :job do
  let(:user_account) { create(:user_account, icn:) }
  let(:icn) { '1013062086V794840' }
  let(:personalisation) { { first_name: 'Jane', date_submitted: 'May 1, 2024' } }
  let(:template_id) { 'template-id-123' }
  let(:api_key_path) { 'Settings.vanotify.services.va_gov.api_key' }
  let(:callback_options) { { callback_metadata: { notification_type: 'confirmation' } } }
  let(:key) { 'fake-redis-key' }

  before do
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')
    allow(Settings.vanotify.services.va_gov).to receive(:api_key).and_return(
      'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    )
  end

  describe '#perform' do
    it 'stores and retrieves personalisation securely' do
      allow(VaNotify::Service).to receive(:new).and_return(instance_double(VaNotify::Service, send_email: true))

      Sidekiq::Testing.inline! do
        key = Sidekiq::AttrPackage.create(personalisation:)
        expect(Sidekiq::AttrPackage.find(key)).to eq({ personalisation: })

        described_class.perform_async(user_account.id, template_id, key, api_key_path, callback_options)
        expect(Sidekiq::AttrPackage.find(key)).to eq({ personalisation: })
      end
    end
  end

  describe '.enqueue' do
    it 'creates an AttrPackage and enqueues the job' do
      expect(Sidekiq::AttrPackage).to receive(:create).with(personalisation:).and_return(key)
      expect(described_class).to receive(:perform_async).with(user_account.id, template_id, key, api_key_path,
                                                              callback_options)

      described_class.enqueue(user_account.id, template_id, personalisation, api_key_path, callback_options)
    end

    it 'uses empty hash for callback_options when not provided' do
      expect(Sidekiq::AttrPackage).to receive(:create).with(personalisation:).and_return(key)
      expect(described_class).to receive(:perform_async).with(user_account.id, template_id, key, api_key_path, {})

      described_class.enqueue(user_account.id, template_id, personalisation, api_key_path)
    end

    context 'when Redis fails' do
      it 'logs error, increments StatsD, and re-raises' do
        error = Redis::ConnectionError.new('Connection refused')
        allow(Sidekiq::AttrPackage).to receive(:create).and_raise(error)

        expect(Rails.logger).to receive(:error).with(
          'VANotify::V2::QueueUserAccountJob enqueue failed',
          { error_class: 'Redis::ConnectionError', template_id: }
        )
        expect(StatsD).to receive(:increment).with('api.vanotify.v2.queue_user_account_job.enqueue_failure')

        expect do
          described_class.enqueue(user_account.id, template_id, personalisation, api_key_path, callback_options)
        end.to raise_error(Redis::ConnectionError)
      end
    end

    context 'when AttrPackage fails' do
      it 'logs error, increments StatsD, and re-raises' do
        error = Sidekiq::AttrPackageError.new('create', 'storage failed')
        allow(Sidekiq::AttrPackage).to receive(:create).and_raise(error)

        expect(Rails.logger).to receive(:error).with(
          'VANotify::V2::QueueUserAccountJob enqueue failed',
          { error_class: 'Sidekiq::AttrPackageError', template_id: }
        )
        expect(StatsD).to receive(:increment).with('api.vanotify.v2.queue_user_account_job.enqueue_failure')

        expect do
          described_class.enqueue(user_account.id, template_id, personalisation, api_key_path, callback_options)
        end.to raise_error(Sidekiq::AttrPackageError)
      end
    end
  end

  describe 'when errors occur' do
    before do
      allow(Sidekiq::AttrPackage).to receive(:delete).with(key)
    end

    it 'raises ArgumentError and logs when AttrPackage.find raises Sidekiq::AttrPackageError' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_raise(
        Sidekiq::AttrPackageError.new('find', 'redis down')
      )

      expect(Rails.logger).to receive(:error).with(
        'VANotify::V2::QueueUserAccountJob AttrPackage error',
        { error_class: 'Sidekiq::AttrPackageError', template_id: }
      )

      expect do
        described_class.new.perform(user_account.id, template_id, key, api_key_path, callback_options)
      end.to raise_error(ArgumentError, 'AttrPackage retrieval failed')
    end

    it 'raises ArgumentError and logs when personalisation data is missing' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return(nil)

      expect(Rails.logger).to receive(:error).with(
        'VANotify::V2::QueueUserAccountJob failed: Missing personalisation data in Redis',
        hash_including(template_id:, attr_package_key_present: true)
      )

      expect do
        described_class.new.perform(user_account.id, template_id, key, api_key_path, callback_options)
      end.to raise_error(ArgumentError, /Missing personalisation data in Redis/)
    end

    it 'handles VANotify::Error (400) and calls handle_backend_exception' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return({ personalisation: })

      va_notify_service = instance_double(VaNotify::Service)
      error = VANotify::BadRequest.new(400, 'bad request')
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow(va_notify_service).to receive(:send_email).and_raise(error)

      expect_any_instance_of(described_class).to receive(:handle_backend_exception).with(error)
      expect(StatsD).to receive(:increment).with('api.vanotify.v2.queue_user_account_job.failure')

      described_class.new.perform(user_account.id, template_id, key, api_key_path, callback_options)
    end

    it 'raises and increments failure stat for VANotify::Error (5xx)' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return({ personalisation: })

      va_notify_service = instance_double(VaNotify::Service)
      error = VANotify::ServerError.new(500, 'server error')
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow(va_notify_service).to receive(:send_email).and_raise(error)

      expect(StatsD).to receive(:increment).with('api.vanotify.v2.queue_user_account_job.failure')

      expect do
        described_class.new.perform(user_account.id, template_id, key, api_key_path, callback_options)
      end.to raise_error(VANotify::ServerError)
    end

    it 'raises and increments failure stat for unexpected errors' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return({ personalisation: })

      va_notify_service = instance_double(VaNotify::Service)
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow(va_notify_service).to receive(:send_email).and_raise(StandardError.new('unexpected'))

      expect(StatsD).to receive(:increment).with('api.vanotify.v2.queue_user_account_job.failure')

      expect do
        described_class.new.perform(user_account.id, template_id, key, api_key_path, callback_options)
      end.to raise_error(StandardError, 'unexpected')
    end

    it 'raises ArgumentError when api_key_path does not start with Settings.' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return({ personalisation: })

      expect do
        described_class.new.perform(user_account.id, template_id, key, 'vanotify.services.va_gov.api_key',
                                    callback_options)
      end.to raise_error(ArgumentError, "API key path must start with 'Settings.': vanotify.services.va_gov.api_key")
    end

    it 'raises ArgumentError when api_key_path is invalid' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return({ personalisation: })

      expect do
        described_class.new.perform(user_account.id, template_id, key, 'Settings.invalid.path.to.api_key',
                                    callback_options)
      end.to raise_error(ArgumentError, 'Unable to resolve API key from path: Settings.invalid.path.to.api_key')
    end
  end

  describe 'sidekiq_retries_exhausted' do
    let(:error) { RuntimeError.new('an error occurred!') }
    let(:msg) do
      {
        'jid' => 123,
        'class' => described_class.to_s,
        'error_class' => 'RuntimeError',
        'error_message' => 'an error occurred!'
      }
    end

    it 'logs error and increments StatsD counter' do
      expect(Rails.logger).to receive(:error).with(
        'VANotify::V2::QueueUserAccountJob retries exhausted',
        { job_id: 123, error_class: 'RuntimeError', error_message: 'an error occurred!' }
      )
      expect(StatsD).to receive(:increment).with(
        'sidekiq.jobs.va_notify/v2/queue_user_account_job.retries_exhausted'
      )

      described_class.sidekiq_retries_exhausted_block.call(msg, error)
    end
  end
end
