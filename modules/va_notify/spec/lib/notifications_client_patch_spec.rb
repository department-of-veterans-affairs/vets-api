# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationsClientPatch do
  let(:speaker_class) do
    Class.new do
      PRODUCTION_BASE_URL = 'https://api.notifications.va.gov'.freeze

      attr_reader :service_id, :secret_token, :base_url

      def validate_uuids!; end
    end.prepend(described_class)
  end

  let(:speaker_class_with_validation) do
    Class.new do
      PRODUCTION_BASE_URL = 'https://api.notifications.va.gov'.freeze

      attr_reader :service_id, :secret_token, :base_url
    end.prepend(described_class)
  end

  describe '#initialize' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_notify_enhanced_uuid_validation).and_return(true)
    end

    context 'when composite ends with UUID api_key' do
      let(:key_name) { 'test-key' }
      let(:service_id) { SecureRandom.uuid }
      let(:api_key) { SecureRandom.uuid }
      let(:composite) { "#{key_name}-#{service_id}-#{api_key}" }

      it 'extracts correct service_id' do
        instance = speaker_class.new(composite)
        expect(instance.service_id).to eq(service_id)
      end

      it 'extracts correct secret_token' do
        instance = speaker_class.new(composite)
        expect(instance.secret_token).to eq(api_key)
      end
    end

    context 'when composite ends with URL-safe api_key' do
      let(:key_name) { 'test-key' }
      let(:service_id) { SecureRandom.uuid }
      let(:api_key) { SecureRandom.urlsafe_base64(64) }
      let(:composite) { "#{key_name}-#{service_id}-#{api_key}" }

      it 'extracts correct service_id' do
        instance = speaker_class.new(composite)
        expect(instance.service_id).to eq(service_id)
      end

      it 'extracts correct secret_token' do
        instance = speaker_class.new(composite)
        expect(instance.secret_token).to eq(api_key)
      end
    end

    context 'with invalid service_id' do
      let(:key_name) { 'test-key' }
      let(:invalid_service_id) { 'xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' } # 36 chars, not valid UUID
      let(:api_key) { SecureRandom.uuid }
      let(:composite) { "#{key_name}-#{invalid_service_id}-#{api_key}" }

      it 'raises ArgumentError' do
        expect { speaker_class_with_validation.new(composite) }
          .to raise_error(ArgumentError, /Invalid service_id format/)
      end
    end

    context 'with invalid api_key' do
      let(:key_name) { 'test-key' }
      let(:service_id) { SecureRandom.uuid }
      let(:invalid_api_key) { 'short-invalid-key' }
      let(:composite) { "#{key_name}-#{service_id}-#{invalid_api_key}" }

      it 'raises ArgumentError' do
        expect { speaker_class_with_validation.new(composite) }
          .to raise_error(ArgumentError, /Invalid secret_token format/)
      end
    end

    context 'when logging detected format' do
      let(:key_name) { 'test-key' }
      let(:service_id) { SecureRandom.uuid }

      it 'logs uuid format for UUID api_key' do
        api_key = SecureRandom.uuid
        composite = "#{key_name}-#{service_id}-#{api_key}"

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/uuid/)
        speaker_class.new(composite)
      end

      it 'logs urlsafe format for URL-safe api_key' do
        api_key = SecureRandom.urlsafe_base64(64)
        composite = "#{key_name}-#{service_id}-#{api_key}"

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/urlsafe/)
        speaker_class.new(composite)
      end
    end

    context 'when logging validation outcome' do
      let(:key_name) { 'test-key' }
      let(:service_id) { SecureRandom.uuid }
      let(:api_key) { SecureRandom.uuid }
      let(:composite) { "#{key_name}-#{service_id}-#{api_key}" }

      it 'logs successful validation' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/validation successful/)
        speaker_class.new(composite)
      end
    end
  end
end
