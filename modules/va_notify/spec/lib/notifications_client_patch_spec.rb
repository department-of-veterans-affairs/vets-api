# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationsClientPatch do
  let(:speaker_class_with_validation) do
    Class.new do
      attr_reader :service_id, :secret_token, :base_url

      def initialize(_secret_token = nil, _base_url = nil); end
    end.prepend(described_class)
  end
  let(:speaker_class) do
    Class.new do
      attr_reader :service_id, :secret_token, :base_url

      def initialize(_secret_token = nil, _base_url = nil); end

      def validate_uuids!; end
    end.prepend(described_class)
  end

  describe 'constants' do
    it 'defines PRODUCTION_BASE_URL' do
      expect(described_class::PRODUCTION_BASE_URL).to eq('https://api.notifications.va.gov')
    end
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

    context 'when va_notify_enhanced_uuid_validation is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_notify_enhanced_uuid_validation).and_return(false)
      end

      let(:key_name) { 'test-key' }
      let(:service_id) { SecureRandom.uuid }
      let(:api_key) { SecureRandom.uuid }
      let(:composite) { "#{key_name}-#{service_id}-#{api_key}" }

      it 'does not execute patch-specific logging' do
        expect(Rails.logger).not_to receive(:info).with(/NotificationsClientPatch/)
        speaker_class.new(composite)
      end
    end

    context 'with invalid input types' do
      context 'with nil secret_token' do
        it 'raises ArgumentError' do
          expect { speaker_class_with_validation.new(nil) }
            .to raise_error(ArgumentError, /Invalid secret_token format/)
        end
      end

      context 'with non-string secret_token (Integer)' do
        it 'raises ArgumentError' do
          expect { speaker_class_with_validation.new(12_345) }
            .to raise_error(ArgumentError, /Invalid secret_token format/)
        end
      end

      context 'with non-string secret_token (Array)' do
        it 'raises ArgumentError' do
          expect { speaker_class_with_validation.new(['token']) }
            .to raise_error(ArgumentError, /Invalid secret_token format/)
        end
      end

      context 'with empty string secret_token' do
        it 'raises ArgumentError' do
          expect { speaker_class_with_validation.new('') }
            .to raise_error(ArgumentError, /Invalid secret_token format/)
        end
      end

      context 'with token shorter than MINIMUM_TOKEN_LENGTH' do
        it 'raises ArgumentError' do
          short_token = 'a' * 74 # MINIMUM_TOKEN_LENGTH is 75
          expect { speaker_class_with_validation.new(short_token) }
            .to raise_error(ArgumentError, /Invalid secret_token format/)
        end
      end
    end

    context 'with boundary conditions' do
      context 'with token exactly at minimum length' do
        let(:service_id) { SecureRandom.uuid }
        let(:api_key) { SecureRandom.uuid }
        let(:composite) { "x-#{service_id}-#{api_key}" } # 1 char key name = exactly 75 chars

        it 'extracts correct service_id' do
          instance = speaker_class.new(composite)
          expect(instance.service_id).to eq(service_id)
        end

        it 'extracts correct secret_token' do
          instance = speaker_class.new(composite)
          expect(instance.secret_token).to eq(api_key)
        end
      end

      context 'when key name contains multiple dashes' do
        let(:key_name) { 'my-app-name-with-dashes' }
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
    end

    context 'with uppercase UUID' do
      let(:key_name) { 'test-key' }
      let(:service_id) { SecureRandom.uuid.upcase }
      let(:api_key) { SecureRandom.uuid.upcase }
      let(:composite) { "#{key_name}-#{service_id}-#{api_key}" }

      it 'validates successfully' do
        expect { speaker_class_with_validation.new(composite) }.not_to raise_error
      end

      it 'extracts correct service_id' do
        instance = speaker_class.new(composite)
        expect(instance.service_id).to eq(service_id)
      end

      it 'extracts correct secret_token' do
        instance = speaker_class.new(composite)
        expect(instance.secret_token).to eq(api_key)
      end
    end

    context 'with invalid urlsafe characters in api_key' do
      let(:key_name) { 'test-key' }
      let(:service_id) { SecureRandom.uuid }

      context 'when api_key contains @' do
        let(:invalid_api_key) { "#{'a' * 85}@" } # 86 chars with invalid character
        let(:composite) { "#{key_name}-#{service_id}-#{invalid_api_key}" }

        it 'raises ArgumentError' do
          expect { speaker_class_with_validation.new(composite) }
            .to raise_error(ArgumentError, /Invalid secret_token format/)
        end
      end

      context 'when api_key contains #' do
        let(:invalid_api_key) { "#{'a' * 85}#" }
        let(:composite) { "#{key_name}-#{service_id}-#{invalid_api_key}" }

        it 'raises ArgumentError' do
          expect { speaker_class_with_validation.new(composite) }
            .to raise_error(ArgumentError, /Invalid secret_token format/)
        end
      end

      context 'when api_key contains +' do
        let(:invalid_api_key) { "#{'a' * 85}+" }
        let(:composite) { "#{key_name}-#{service_id}-#{invalid_api_key}" }

        it 'raises ArgumentError' do
          expect { speaker_class_with_validation.new(composite) }
            .to raise_error(ArgumentError, /Invalid secret_token format/)
        end
      end
    end
  end
end
