# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client, '#status' do
  let(:client) { described_class.new(session: { user_id: '10616687' }) }

  before do
    allow(client).to receive(:token_headers).and_return({})
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
