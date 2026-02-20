# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client, '#message_sending' do
  let(:client) { described_class.new(session: { user_id: '10616687' }) }
  let(:mhv_correlation_id) { '123456789012' }
  let(:user) { build(:user, :mhv) }

  before do
    allow(client).to receive_messages(token_headers: {}, current_user: user)
    allow(user).to receive(:mhv_correlation_id).and_return(mhv_correlation_id)
  end

  describe '#perform_with_logging' do
    let(:path) { 'message' }
    let(:args) { { recipient_id: 987_654, body: 'test message' } }
    let(:error) { StandardError.new('connection timeout') }

    context 'when the request succeeds' do
      let(:response_body) { { data: { id: 1 } } }

      before do
        allow(client).to receive(:perform).and_return(OpenStruct.new(body: response_body))
      end

      it 'returns the response body' do
        result = client.send(:perform_with_logging, :post, path, args)
        expect(result).to eq(response_body)
      end

      it 'does not log an error' do
        expect(client).not_to receive(:log_message_to_rails)
        client.send(:perform_with_logging, :post, path, args)
      end
    end

    context 'when the request fails' do
      before do
        allow(client).to receive(:perform).and_raise(error)
      end

      it 'logs the error with correct message, level, and context' do
        expect(client).to receive(:log_message_to_rails).with(
          'MHV SM: Message Send Failed',
          'error',
          hash_including(
            error: 'connection timeout',
            path: 'message',
            client_type: 'my_health'
          )
        )

        expect { client.send(:perform_with_logging, :post, path, args) }
          .to raise_error(StandardError, 'connection timeout')
      end

      it 're-raises the original exception' do
        allow(client).to receive(:log_message_to_rails)

        expect { client.send(:perform_with_logging, :post, path, args) }
          .to raise_error(error)
      end

      it 'masks recipient_id to last 6 digits' do
        expect(client).to receive(:log_message_to_rails).with(
          anything, anything,
          hash_including(recipient_id: '***987654')
        )

        expect { client.send(:perform_with_logging, :post, path, args) }
          .to raise_error(StandardError)
      end

      it 'masks mhv_correlation_id to last 6 digits' do
        expect(client).to receive(:log_message_to_rails).with(
          anything, anything,
          hash_including(mhv_correlation_id: '****789012')
        )

        expect { client.send(:perform_with_logging, :post, path, args) }
          .to raise_error(StandardError)
      end

      it 'includes the path in the log context' do
        expect(client).to receive(:log_message_to_rails).with(
          anything, anything,
          hash_including(path: 'message')
        )

        expect { client.send(:perform_with_logging, :post, path, args) }
          .to raise_error(StandardError)
      end
    end

    context 'when recipient_id is nil' do
      let(:args) { { recipient_id: nil, body: 'test' } }

      before do
        allow(client).to receive(:perform).and_raise(error)
      end

      it 'handles nil recipient_id gracefully with masked placeholder' do
        expect(client).to receive(:log_message_to_rails).with(
          anything, anything,
          hash_including(recipient_id: '***')
        )

        expect { client.send(:perform_with_logging, :post, path, args) }
          .to raise_error(StandardError)
      end
    end

    context 'when current_user is nil' do
      before do
        allow(client).to receive(:current_user).and_return(nil)
        allow(client).to receive(:perform).and_raise(error)
      end

      it 'handles nil current_user gracefully with masked placeholder' do
        expect(client).to receive(:log_message_to_rails).with(
          anything, anything,
          hash_including(mhv_correlation_id: '****')
        )

        expect { client.send(:perform_with_logging, :post, path, args) }
          .to raise_error(StandardError)
      end
    end
  end
end
