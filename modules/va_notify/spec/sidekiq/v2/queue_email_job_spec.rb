# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'

RSpec.describe VANotify::V2::QueueEmailJob, type: :job do
  let(:personalisation) { { first_name: 'Jane', date_submitted: 'May 1, 2024' } }
  let(:email) { 'user@example.com' }
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

  it 'stores and retrieves personalisation securely' do
    allow(VaNotify::Service).to receive(:new).and_return(instance_double(VaNotify::Service, send_email: true))
    Sidekiq::Testing.inline! do
      key = Sidekiq::AttrPackage.create(attrs: { email:, personalisation: })
      expect(Sidekiq::AttrPackage.find(key)).to eq(attrs: { email:, personalisation: })

      VANotify::V2::QueueEmailJob.perform_async(template_id, key, api_key_path, callback_options)
      expect(Sidekiq::AttrPackage.find(key)).to eq(attrs: { email:, personalisation: })
    end
  end

  context 'when errors occur' do
    before do
      allow(Sidekiq::AttrPackage).to receive(:delete).with(key)
    end

    it 'raises ArgumentError and logs when AttrPackage.find raises Sidekiq::AttrPackageError' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_raise(Sidekiq::AttrPackageError.new('find',
                                                                                                      'redis down'))
      expect(Rails.logger).to receive(:error).with('VANotify::V2::QueueEmailJob AttrPackage error',
                                                   hash_including(error: /redis down/))
      expect do
        described_class.new.perform(template_id, key, api_key_path, callback_options)
      end.to raise_error(ArgumentError, /redis down/)
    end

    it 'raises ArgumentError and logs when personalisation data is missing' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return(nil)
      expect(Rails.logger).to receive(:error).with(
        'VANotify::V2::QueueEmailJob failed: Missing personalisation data in Redis',
        hash_including(template_id:, attr_package_key_present: true)
      )
      expect do
        described_class.new.perform(template_id, key, api_key_path, callback_options)
      end.to raise_error(ArgumentError, /Missing personalisation data in Redis/)
    end

    it 'handles VANotify::Error (400) and calls handle_backend_exception' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return(attrs: { email:, personalisation: })
      va_notify_service = instance_double(VaNotify::Service)
      error = VANotify::BadRequest.new(400, 'bad request')
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow(va_notify_service).to receive(:send_email).and_raise(error)
      expect_any_instance_of(described_class).to receive(:handle_backend_exception).with(error)
      expect(StatsD).to receive(:increment).with('api.vanotify.v2.send_email.failure')
      described_class.new.perform(template_id, key, api_key_path, callback_options)
    end

    it 'raises and logs for VANotify::Error (5xx)' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return(attrs: { email:, personalisation: })
      va_notify_service = instance_double(VaNotify::Service)
      error = VANotify::ServerError.new(500, 'server error')
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow(va_notify_service).to receive(:send_email).and_raise(error)
      expect(StatsD).to receive(:increment).with('api.vanotify.v2.send_email.failure')
      expect do
        described_class.new.perform(template_id, key, api_key_path, callback_options)
      end.to raise_error(VANotify::ServerError)
    end

    it 'raises ArgumentError when api_key_path does not start with Settings.' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return(attrs: { email:, personalisation: })

      expect do
        described_class.new.perform(template_id, key, 'vanotify.services.va_gov.api_key', callback_options)
      end.to raise_error(ArgumentError, "API key path must start with 'Settings.': vanotify.services.va_gov.api_key")
    end

    it 'raises ArgumentError when api_key_path is invalid' do
      allow(Sidekiq::AttrPackage).to receive(:find).with(key).and_return(attrs: { email:, personalisation: })

      expect do
        described_class.new.perform(template_id, key, 'Settings.invalid.path.to.api_key', callback_options)
      end.to raise_error(ArgumentError, 'Unable to resolve API key from path: Settings.invalid.path.to.api_key')
    end
  end
end
