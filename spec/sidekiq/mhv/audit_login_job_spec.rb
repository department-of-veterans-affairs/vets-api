# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHV::AuditLoginJob do
  let(:mhv_correlation_id) { '12345' }
  let(:authenticated_client) do
    MHVLogging::Client.new(session: { user_id: mhv_correlation_id })
  end

  before do
    allow(MHVLogging::Client).to receive(:new).and_return(authenticated_client)
    allow(authenticated_client).to receive(:authenticate).and_return(authenticated_client)
    allow(authenticated_client).to receive(:auditlogin)
  end

  describe 'perform' do
    it 'calls MHV audit client with correlation id' do
      expect(MHVLogging::Client).to receive(:new).with(session: { user_id: mhv_correlation_id })
      expect(authenticated_client).to receive(:authenticate)
      expect(authenticated_client).to receive(:auditlogin)

      described_class.new.perform(mhv_correlation_id)
    end

    context 'with invalid parameters' do
      it 'returns early if mhv_correlation_id is blank' do
        expect(MHVLogging::Client).not_to receive(:new)
        described_class.new.perform(nil)
      end

      it 'returns early if mhv_last_signed_in is present' do
        expect(MHVLogging::Client).not_to receive(:new)
        described_class.new.perform(mhv_correlation_id, Time.current.iso8601)
      end
    end

    it 'posts an audit log when not logged in' do
      VCR.use_cassette('mhv_logging_client/audits/submits_an_audit_log_for_signing_in') do
        expect(authenticated_client).to receive(:authenticate)
        expect(authenticated_client).to receive(:auditlogin)

        described_class.new.perform(mhv_correlation_id)
      end
    end
  end
end
