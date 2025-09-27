# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client, '#status' do
  let(:client) { described_class.new(session: { user_id: '10616687' }) }

  before do
    allow(client).to receive(:token_headers).and_return({})
  end

  describe '#get_message_status' do
    it 'calls the expected path and normalizes the response' do
      response_body = {
        data: {
          message_id: 123,
          status: 'sent',
          is_oh_message: true,
          oh_secure_message_id: '54280239861.0.-4.prsnl'
        }
      }
      expect(client).to receive(:perform)
        .with(:get, 'messages/123/status', nil, anything)
        .and_return(double(body: response_body))

      result = client.get_message_status(123)

      expect(result[:message_id]).to eq(123)
      expect(result[:status]).to eq('SENT')
      expect(result[:is_oh_message]).to be(true)
      expect(result[:oh_secure_message_id]).to eq('54280239861.0.-4.prsnl')
    end
  end

  describe '#poll_message_status' do
    before do
      # Avoid slowing down specs
      allow_any_instance_of(SM::Client).to receive(:sleep)
    end

    it 'polls until a terminal status is reached and returns the result' do
      allow(client).to receive(:get_message_status)
        .with(55).and_return({ status: 'IN_PROGRESS' },
                             { status: 'IN_PROGRESS' },
                             { status: 'SENT' })

      result = client.poll_message_status(55, timeout_seconds: 10, interval_seconds: 0.01, max_errors: 2)

      expect(result[:status]).to eq('SENT')
    end

    it 'raises GatewayTimeout when deadline is reached without reaching a terminal status' do
      # immediate timeout to avoid calling get_message_status
      expect do
        client.poll_message_status(77, timeout_seconds: 0, interval_seconds: 0.01, max_errors: 2)
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end

    it 'retries transient errors up to max_errors and then raises GatewayTimeout' do
      transient_error = Common::Exceptions::BackendServiceException.new('VA900', {}, 500)
      allow(client).to receive(:get_message_status).and_raise(transient_error)

      expect do
        client.poll_message_status(88, timeout_seconds: 10, interval_seconds: 0.01, max_errors: 2)
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  describe 'auto-poll integration on send' do
    before do
      # Simulate successful post create response from SM (HTTP layer stubbed)
      allow(client).to receive(:perform).and_return(
        double(body: { data: { id: 42, is_oh_message: true }, metadata: {} })
      )
    end

    context 'when message is OH' do
      it 'polls and returns message on SENT' do
        expect(client).to receive(:poll_message_status).with(42, hash_including(timeout_seconds: 60)).and_return(
          { message_id: 42, status: 'SENT', is_oh_message: true }
        )

        msg = client.post_create_message({ subject: 's', category: 'OTHER', recipient_id: 1, body: 'b' },
                                         poll_for_status: true)

        expect(msg).to be_a(Message)
        expect(msg.id).to eq(42)
        expect(msg.is_oh_message).to be(true)
      end

      it 'raises UnprocessableEntity on FAILED' do
        expect(client).to receive(:poll_message_status).with(42, hash_including(timeout_seconds: 60)).and_return(
          { message_id: 42, status: 'FAILED', is_oh_message: true }
        )

        expect do
          client.post_create_message({ subject: 's', category: 'OTHER', recipient_id: 1, body: 'b' },
                                     poll_for_status: true)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end

      it 'raises UnprocessableEntity on INVALID' do
        expect(client).to receive(:poll_message_status).with(42, hash_including(timeout_seconds: 60)).and_return(
          { message_id: 42, status: 'INVALID', is_oh_message: true }
        )

        expect do
          client.post_create_message({ subject: 's', category: 'OTHER', recipient_id: 1, body: 'b' },
                                     poll_for_status: true)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end

      it 'returns message on UNKNOWN and NOT_SUPPORTED terminal statuses' do
        %w[UNKNOWN NOT_SUPPORTED].each do |terminal|
          allow(client).to receive(:perform).and_return(
            double(body: { data: { id: 52, is_oh_message: true }, metadata: {} })
          )
          expect(client).to receive(:poll_message_status).with(52, hash_including(timeout_seconds: 60)).and_return(
            { message_id: 52, status: terminal, is_oh_message: true }
          )

          msg = client.post_create_message({ subject: 's', category: 'OTHER', recipient_id: 1, body: 'b' },
                                           poll_for_status: true)
          expect(msg).to be_a(Message)
          expect(msg.id).to eq(52)
          expect(msg.is_oh_message).to be(true)
        end
      end
    end

    context 'when message is not OH' do
      it 'does not poll and returns the message' do
        # Return non-OH record
        allow(client).to receive(:perform).and_return(
          double(body: { data: { id: 99, is_oh_message: false }, metadata: {} })
        )
        expect(client).not_to receive(:poll_message_status)

        msg = client.post_create_message(subject: 's', category: 'OTHER', recipient_id: 1, body: 'b')

        expect(msg).to be_a(Message)
        expect(msg.id).to eq(99)
        expect(msg.is_oh_message).to be(false)
      end
    end

    context 'reply variants' do
      it 'polls for OH replies and returns message on SENT' do
        # First call (reply) returns OH message
        allow(client).to receive(:perform).and_return(
          double(body: { data: { id: 77, is_oh_message: true }, metadata: {} })
        )
        expect(client).to receive(:poll_message_status).with(77, hash_including(timeout_seconds: 60)).and_return(
          { message_id: 77, status: 'SENT', is_oh_message: true }
        )

        msg = client.post_create_message_reply(55, { subject: 's', category: 'OTHER', recipient_id: 1, body: 'b' },
                                               poll_for_status: true)

        expect(msg).to be_a(Message)
        expect(msg.id).to eq(77)
        expect(msg.is_oh_message).to be(true)
      end
    end
  end
end
