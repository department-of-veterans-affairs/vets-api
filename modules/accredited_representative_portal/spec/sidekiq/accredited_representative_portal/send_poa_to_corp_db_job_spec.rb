# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

module AccreditedRepresentativePortal
  RSpec.describe SendPoaToCorpDbJob, type: :job do
    let(:poa_request) { create(:power_of_attorney_request) }

    describe '#perform' do
      context 'when the POA request exists and has not been sent' do
        it 'calls the SendPoaToCorpDbService with the request and sets sent_to_corpdb_at' do
          allow(AccreditedRepresentativePortal::SendPoaToCorpDbService).to receive(:call).with(poa_request)

          described_class.new.perform(poa_request.id)

          expect(AccreditedRepresentativePortal::SendPoaToCorpDbService).to have_received(:call).with(poa_request)
          expect(poa_request.reload.sent_to_corpdb_at).not_to be_nil
        end
      end

      context 'when the POA request has already been sent' do
        it 'does not call the service again' do
          poa_request.update!(sent_to_corpdb_at: Time.current)

          expect(AccreditedRepresentativePortal::SendPoaToCorpDbService).not_to receive(:call)
          described_class.new.perform(poa_request.id)
        end
      end

      context 'when the POA request does not exist' do
        it 'logs an error for RecordNotFound and does not raise' do
          allow(Rails.logger).to receive(:error)
          described_class.new.perform('nonexistent_id')
          expect(Rails.logger).to have_received(:error).with(/POA request not found/)
        end
      end

      context 'when the service raises a Faraday error' do
        it 'logs the error and re-raises for retry' do
          allow(AccreditedRepresentativePortal::SendPoaToCorpDbService)
            .to receive(:call).and_raise(Faraday::ClientError.new(double(response: { status: 500 })))
          allow(Rails.logger).to receive(:error)

          expect do
            described_class.new.perform(poa_request.id)
          end.to raise_error(Faraday::ClientError)

          expect(Rails.logger).to have_received(:error).with(
            /Failed to send POA to CorpDB/,
            hash_including(:error, :poa_request_id)
          )
        end
      end

      context 'when the service raises an unexpected error' do
        it 'logs the error and re-raises' do
          allow(AccreditedRepresentativePortal::SendPoaToCorpDbService)
            .to receive(:call).and_raise(StandardError.new('unexpected failure'))
          allow(Rails.logger).to receive(:error)

          expect do
            described_class.new.perform(poa_request.id)
          end.to raise_error(StandardError, 'unexpected failure')

          expect(Rails.logger).to have_received(:error).with(
            /Unexpected error sending POA to CorpDB/,
            hash_including(:error, :poa_request_id)
          )
        end
      end
    end
  end
end
