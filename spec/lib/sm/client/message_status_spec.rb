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
                                                                 hash_including(timeout_seconds: 60))

            expect do
              client.post_create_message(message_params, is_oh: true)
            end.not_to raise_error
          end
        end
      end

      it 'raises BackendServiceException on FAILED' do
        VCR.use_cassette('sm_client/messages/creates/status_failed') do
          VCR.use_cassette('sm_client/messages/creates/a_new_oh_message_without_attachments') do
            expect { client.post_create_message(message_params, is_oh: true) }
              .to raise_error(Common::Exceptions::BackendServiceException) do |error|
                expect(error.status_code).to eq(400)
                expect(error.errors.first[:code]).to eq('SM98')
                expect(error.errors.first[:detail]).to eq('Oracle Health message send failed')
            end
          end
        end
      end

      it 'raises BackendServiceException on INVALID' do
        VCR.use_cassette('sm_client/messages/creates/status_invalid') do
          VCR.use_cassette('sm_client/messages/creates/a_new_oh_message_without_attachments') do
            expect { client.post_create_message(message_params, is_oh: true) }
              .to raise_error(Common::Exceptions::BackendServiceException) do |error|
                expect(error.status_code).to eq(400)
                expect(error.errors.first[:code]).to eq('SM98')
                expect(error.errors.first[:detail]).to eq('Oracle Health message send failed')
            end
          end
        end
      end

      it 'returns message on UNKNOWN and NOT_SUPPORTED terminal statuses' do
        %w[UNKNOWN NOT_SUPPORTED].each do |terminal|
          VCR.use_cassette("sm_client/messages/creates/status_#{terminal.downcase}") do
            VCR.use_cassette('sm_client/messages/creates/a_new_oh_message_without_attachments') do
              expect(client).to receive(:poll_message_status).with(674_838,
                                                                   hash_including(timeout_seconds: 60))

              client.post_create_message(message_params, is_oh: true)
            end
          end
        end
      end
    end

    context 'when message is not OH' do
      it 'does not poll and returns the message' do
        VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
          expect(client).not_to receive(:poll_message_status)

          msg = client.post_create_message(subject: 's', category: 'OTHER', recipient_id: 1, body: 'b')

          expect(msg).to be_a(Message)
          expect(msg.id).to eq(674_838)
          expect(msg.is_oh_message).to be(false)
        end
      end
    end

    context 'reply variants' do
      it 'returns reply message' do
        VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
          expect(client).not_to receive(:poll_message_status)

          msg = client.post_create_message_reply(674_838, { subject: 's', category: 'OTHER',
                                                            recipient_id: 1, body: 'b' },
                                                 is_oh: false)

          expect(msg).to be_a(Message)
          expect(msg.id).to eq(674_874)
          expect(msg.is_oh_message).to be(false)
        end
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
      VCR.use_cassette('sm_client/messages/creates/status_in_progress', allow_playback_repeats: true) do
        expect do
          client.send(:poll_message_status, 674_838, timeout_seconds: 0.01, interval_seconds: 0)
        end.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    it 'raises error after exceeding max_errors consecutive errors' do
      VCR.use_cassette('sm_client/messages/creates/status_error', allow_playback_repeats: true) do
        expect { client.send(:poll_message_status, 674_838, max_errors: 2) }.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end

    it 'continues polling on non-terminal statuses and returns when terminal' do
      VCR.use_cassette('sm_client/messages/creates/status_polling_sequence') do
        result = client.send(:poll_message_status, 674_838)
        expect(result).to eq({ message_id: 674_838, status: 'SENT', is_oh_message: true,
                               oh_secure_message_id: '54282597705.0.-4.prsnl' })
      end
    end

    it 'resets consecutive_errors on successful call' do
      VCR.use_cassette('sm_client/messages/creates/status_error_reset') do
        result = client.send(:poll_message_status, 674_838, max_errors: 2)
        expect(result).to eq({ message_id: 674_838, status: 'SENT', is_oh_message: true,
                               oh_secure_message_id: '54282597705.0.-4.prsnl' })
      end
    end
  end
end
