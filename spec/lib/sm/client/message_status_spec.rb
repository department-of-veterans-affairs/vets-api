# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client, '#status' do
  let(:client) { described_class.new(session: { user_id: '10616687' }) }
  let(:message_params) do
    { subject: 'CI Run', body: 'Continuous Integration', is_oh_message: true }
  end

  before do
    allow(client).to receive(:token_headers).and_return({})
  end

  describe 'auto-poll integration on send' do
    context 'when message is OH' do
      it 'polls and returns message on SENT' do
        VCR.use_cassette('sm_client/messages/creates/status_sent') do
          VCR.use_cassette('sm_client/messages/creates/a_new_oh_message_without_attachments') do
            expect(client).to receive(:poll_message_status).with(674_838,
                                                                 hash_including(timeout_seconds: 60)).and_return(
                                                                   { message_id: 674_838, status: 'SENT',
                                                                     is_oh_message: true }
                                                                 )

            client.post_create_message(message_params, poll_for_status: true)
          end
        end
      end

      it 'raises UnprocessableEntity on FAILED' do
        VCR.use_cassette('sm_client/messages/creates/status_failed') do
          VCR.use_cassette('sm_client/messages/creates/a_new_oh_message_without_attachments') do
            expect(client).to receive(:poll_message_status).with(674_838,
                                                                 hash_including(timeout_seconds: 60)).and_return(
                                                                   { message_id: 674_838, status: 'FAILED',
                                                                     is_oh_message: true }
                                                                 )

            expect do
              client.post_create_message(message_params, poll_for_status: true)
            end.to raise_error(Common::Exceptions::UnprocessableEntity)
          end
        end
      end

      it 'raises UnprocessableEntity on INVALID' do
        VCR.use_cassette('sm_client/messages/creates/status_invalid') do
          VCR.use_cassette('sm_client/messages/creates/a_new_oh_message_without_attachments') do
            expect(client).to receive(:poll_message_status).with(674_838,
                                                                 hash_including(timeout_seconds: 60)).and_return(
                                                                   { message_id: 674_838, status: 'INVALID',
                                                                     is_oh_message: true }
                                                                 )

            expect do
              client.post_create_message(message_params, poll_for_status: true)
            end.to raise_error(Common::Exceptions::UnprocessableEntity)
          end
        end
      end

      it 'returns message on UNKNOWN and NOT_SUPPORTED terminal statuses' do
        %w[UNKNOWN NOT_SUPPORTED].each do |terminal|
          VCR.use_cassette("sm_client/messages/creates/status_#{terminal.downcase}") do
            VCR.use_cassette('sm_client/messages/creates/a_new_oh_message_without_attachments') do
              expect(client).to receive(:poll_message_status).with(674_838,
                                                                   hash_including(timeout_seconds: 60)).and_return(
                                                                     { message_id: 674_838, status: terminal,
                                                                       is_oh_message: true }
                                                                   )

              client.post_create_message(message_params, poll_for_status: true)
            end
          end
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

  describe '#poll_message_status' do
    let(:client) { described_class.new(session: { user_id: '10616687' }) }

    before do
      allow(client).to receive(:token_headers).and_return({})
    end

    %w[SENT FAILED INVALID UNKNOWN NOT_SUPPORTED].each do |terminal_status|
      it "returns result when status is #{terminal_status}" do
        VCR.use_cassette("sm_client/messages/creates/status_#{terminal_status.downcase}") do
          result = client.send(:poll_message_status, 674_838)
          expect(result).to eq({ message_id: 674_838, status: terminal_status, is_oh_message: true,
                                 oh_secure_message_id: '54282597705.0.-4.prsnl' })
        end
      end
    end

    it 'raises GatewayTimeout when timeout is reached' do
      allow(client).to receive(:get_message_status).and_return({ status: 'IN_PROGRESS' })
      expect { client.send(:poll_message_status, 123, timeout_seconds: 0) }.to raise_error(Common::Exceptions::GatewayTimeout)
    end

    it 'raises error after exceeding max_errors consecutive errors' do
      allow(client).to receive(:get_message_status).and_raise(StandardError.new('API error'))
      expect { client.send(:poll_message_status, 123, max_errors: 2) }.to raise_error(StandardError)
    end

    it 'continues polling on non-terminal statuses and returns when terminal' do
      call_count = 0
      allow(client).to receive(:get_message_status) do
        call_count += 1
        if call_count < 3
          { status: 'IN_PROGRESS' }
        else
          { status: 'SENT' }
        end
      end
      allow(client).to receive(:sleep)
      result = client.send(:poll_message_status, 123)
      expect(result).to eq({ status: 'SENT' })
      expect(call_count).to eq(3)
    end

    it 'resets consecutive_errors on successful call' do
      call_count = 0
      allow(client).to receive(:get_message_status) do
        call_count += 1
        if call_count == 1
          raise StandardError.new('API error')
        elsif call_count == 2
          raise StandardError.new('API error')
        else
          { status: 'SENT' }
        end
      end
      allow(client).to receive(:sleep)
      result = client.send(:poll_message_status, 123, max_errors: 2)
      expect(result).to eq({ status: 'SENT' })
      expect(call_count).to eq(3)
    end
  end
end
