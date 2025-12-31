# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationsClientPatch do
  let(:test_speaker_class) do
    Class.new do
      def initialize(service_id = nil, secret_token = nil)
        @service_id = service_id
        @secret_token = secret_token

        validate_uuids!
      end

      def validate_uuids!
        raise ArgumentError, 'Original method called'
      end
    end
  end

  let(:speaker_class) { test_speaker_class.prepend(NotificationsClientPatch) }

  describe '#validate_uuids!' do
    context 'when va_notify_enhanced_uuid_validation is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_notify_enhanced_uuid_validation).and_return(true)
      end

      context 'with valid service_id and secret_token' do
        it 'does not raise error for valid UUID service_id and UUID secret_token' do
          service_id = '550e8400-e29b-41d4-a716-446655440000'
          secret_token = '660f9500-f3ab-52e5-b827-557766551111'

          expect { speaker_class.new(service_id, secret_token) }.not_to raise_error
        end

        it 'does not raise error for valid UUID service_id and token_urlsafe secret_token' do
          service_id = '550e8400-e29b-41d4-a716-446655440000'
          # emulates Python secrets.token_urlsafe(64)
          secret_token = SecureRandom.urlsafe_base64(64)

          expect { speaker_class.new(service_id, secret_token) }.not_to raise_error
        end

        it 'handles uppercase UUIDs' do
          service_id = '550E8400-E29B-41D4-A716-446655440000'
          secret_token = '660F9500-F3AB-52E5-B827-557766551111'

          expect { speaker_class.new(service_id, secret_token) }.not_to raise_error
        end
      end

      context 'with invalid service_id' do
        it 'raises ArgumentError for malformed service_id UUID' do
          invalid_service_id = '550e8400-e29b-41d4-a716-44665544000' # missing char
          valid_secret_token = '660f9500-f3ab-52e5-b827-557766551111'

          expect { speaker_class.new(invalid_service_id, valid_secret_token) }
            .to raise_error(ArgumentError, "Invalid service_id format: #{invalid_service_id}")
        end

        it 'raises ArgumentError for non-UUID service_id' do
          invalid_service_id = 'not-a-uuid'
          valid_secret_token = '660f9500-f3ab-52e5-b827-557766551111'

          expect { speaker_class.new(invalid_service_id, valid_secret_token) }
            .to raise_error(ArgumentError, "Invalid service_id format: #{invalid_service_id}")
        end

        it 'raises ArgumentError for nil service_id' do
          valid_secret_token = '660f9500-f3ab-52e5-b827-557766551111'

          expect { speaker_class.new(nil, valid_secret_token) }
            .to raise_error(ArgumentError, 'Invalid service_id format: ')
        end
      end

      context 'with invalid secret_token' do
        it 'raises ArgumentError for malformed UUID secret_token' do
          valid_service_id = '550e8400-e29b-41d4-a716-446655440000'
          invalid_secret_token = '660f9500-f3ab-52e5-b827-55776655111' # missing char

          expect { speaker_class.new(valid_service_id, invalid_secret_token) }
            .to raise_error(ArgumentError, "Invalid secret_token format: #{invalid_secret_token}")
        end

        it 'raises ArgumentError for short token' do
          valid_service_id = '550e8400-e29b-41d4-a716-446655440000'
          short_token = 'a' * 30

          expect { speaker_class.new(valid_service_id, short_token) }
            .to raise_error(ArgumentError, "Invalid secret_token format: #{short_token}")
        end

        it 'raises ArgumentError for token with invalid characters' do
          valid_service_id = '550e8400-e29b-41d4-a716-446655440000'
          invalid_token = "#{'a' * 86}@\#$"

          expect { speaker_class.new(valid_service_id, invalid_token) }
            .to raise_error(ArgumentError, "Invalid secret_token format: #{invalid_token}")
        end

        it 'raises ArgumentError for nil secret_token' do
          valid_service_id = '550e8400-e29b-41d4-a716-446655440000'

          expect { speaker_class.new(valid_service_id, nil) }
            .to raise_error(ArgumentError, 'Invalid secret_token format: ')
        end
      end
    end

    context 'when va_notify_enhanced_uuid_validation is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_notify_enhanced_uuid_validation).and_return(false)
      end

      it 'calls the original validate_uuids! method (super)' do
        # The original method raises 'Original method called' - we SHOULD see that
        valid_service_id = '550e8400-e29b-41d4-a716-446655440000'
        valid_secret_token = '660f9500-f3ab-52e5-b827-557766551111'

        expect { speaker_class.new(valid_service_id, valid_secret_token) }
          .to raise_error(ArgumentError, 'Original method called')
      end
    end
  end
end
