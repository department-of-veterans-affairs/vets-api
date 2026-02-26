# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/medical_records_log'

RSpec.describe MedicalRecords::MedicalRecordsLog do
  subject(:log) { described_class.new(user:) }

  let(:user) { build(:user, :loa3) }

  describe '#info' do
    it 'logs an info-level structured message' do
      expect(Rails.logger).to receive(:info).with(
        hash_including(
          service: 'medical_records',
          resource: described_class::CLINICAL_NOTES,
          action: 'index',
          total: 5
        )
      )

      log.info(resource: described_class::CLINICAL_NOTES, action: 'index', total: 5)
    end

    it 'strips PII keys from metadata' do
      expect(Rails.logger).to receive(:info) do |payload|
        expect(payload).not_to have_key(:icn)
        expect(payload).not_to have_key(:ssn)
        expect(payload).not_to have_key(:email)
        expect(payload).not_to have_key(:user_uuid)
        expect(payload[:total]).to eq(3)
      end

      log.info(resource: described_class::CLINICAL_NOTES, action: 'index',
               total: 3, icn: '123V456', ssn: '999-00-1234',
               email: 'vet@example.com', user_uuid: 'abc-123')
    end

    it 'strips PII keys from nested hashes' do
      expect(Rails.logger).to receive(:info) do |payload|
        expect(payload[:context]).to eq({ status: 'ok' })
      end

      log.info(resource: described_class::CLINICAL_NOTES, action: 'show',
               context: { status: 'ok', icn: '123V456' })
    end

    it 'strips PII keys from hashes inside arrays' do
      expect(Rails.logger).to receive(:info) do |payload|
        expect(payload[:items]).to eq([{ id: 1 }, { id: 2 }])
      end

      log.info(resource: described_class::ALLERGIES, action: 'index',
               items: [{ id: 1, ssn: '111' }, { id: 2, email: 'x@y.com' }])
    end
  end

  describe '#warn' do
    it 'logs a warn-level structured message' do
      expect(Rails.logger).to receive(:warn).with(
        hash_including(
          service: 'medical_records',
          resource: described_class::CLINICAL_NOTES,
          action: 'index',
          anomaly: 'high_filter_rate'
        )
      )

      log.warn(resource: described_class::CLINICAL_NOTES, action: 'index', anomaly: 'high_filter_rate')
    end
  end

  describe '#error' do
    it 'logs an error-level structured message' do
      expect(Rails.logger).to receive(:error).with(
        hash_including(
          service: 'medical_records',
          resource: described_class::CLINICAL_NOTES,
          action: 'show',
          error_class: 'TimeoutError'
        )
      )

      log.error(resource: described_class::CLINICAL_NOTES, action: 'show', error_class: 'TimeoutError')
    end

    it 'strips PII from error metadata' do
      expect(Rails.logger).to receive(:error) do |payload|
        expect(payload).not_to have_key(:mhv_correlation_id)
        expect(payload[:error_message]).to eq('boom')
      end

      log.error(resource: described_class::CLINICAL_NOTES, action: 'show',
                error_message: 'boom', mhv_correlation_id: 'abc123')
    end
  end

  describe '#diagnostic' do
    context 'when the domain-specific toggle is enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_clinical_notes_diagnostic, user)
          .and_return(true)
      end

      it 'logs an info-level message with diagnostic context' do
        expect(Rails.logger).to receive(:info).with(
          hash_including(
            service: 'medical_records',
            resource: described_class::CLINICAL_NOTES,
            action: 'filter',
            log_level_context: 'diagnostic',
            filter_rate: 40.0
          )
        )

        result = log.diagnostic(resource: described_class::CLINICAL_NOTES, action: 'filter', filter_rate: 40.0)
        expect(result).to be true
      end

      it 'does not check the global toggle' do
        allow(Rails.logger).to receive(:info)
        expect(Flipper).not_to receive(:enabled?)
          .with(:mhv_medical_records_diagnostic_logging, user)

        log.diagnostic(resource: described_class::CLINICAL_NOTES, action: 'filter', filter_rate: 1.0)
      end
    end

    context 'when domain toggle is off but global toggle is on' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_clinical_notes_diagnostic, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_diagnostic_logging, user)
          .and_return(true)
      end

      it 'logs via the global fallback' do
        expect(Rails.logger).to receive(:info).with(
          hash_including(resource: described_class::CLINICAL_NOTES, log_level_context: 'diagnostic')
        )

        result = log.diagnostic(resource: described_class::CLINICAL_NOTES, action: 'filter', filter_rate: 40.0)
        expect(result).to be true
      end
    end

    context 'when both toggles are disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_clinical_notes_diagnostic, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_diagnostic_logging, user)
          .and_return(false)
      end

      it 'does not log anything' do
        expect(Rails.logger).not_to receive(:info)

        result = log.diagnostic(resource: described_class::CLINICAL_NOTES, action: 'filter', filter_rate: 40.0)
        expect(result).to be false
      end
    end

    context 'when resource has no domain toggle' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_diagnostic_logging, user)
          .and_return(true)
      end

      it 'falls back to global toggle for unknown resources' do
        expect(Rails.logger).to receive(:info).with(
          hash_including(resource: 'imaging', log_level_context: 'diagnostic')
        )

        result = log.diagnostic(resource: 'imaging', action: 'index', count: 5)
        expect(result).to be true
      end
    end

    context 'when no user is provided' do
      let(:user) { nil }

      it 'does not log anything' do
        expect(Rails.logger).not_to receive(:info)

        result = log.diagnostic(resource: described_class::CLINICAL_NOTES, action: 'filter', filter_rate: 40.0)
        expect(result).to be false
      end
    end

    it 'strips PII from diagnostic metadata' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_medical_records_clinical_notes_diagnostic, user)
        .and_return(true)

      expect(Rails.logger).to receive(:info) do |payload|
        expect(payload).not_to have_key(:icn)
        expect(payload[:doc_ref_total]).to eq(20)
      end

      log.diagnostic(resource: described_class::CLINICAL_NOTES, action: 'filter',
                     doc_ref_total: 20, icn: '123V456')
    end
  end

  describe '#diagnostic_enabled?' do
    context 'when domain toggle is on' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_clinical_notes_diagnostic, user)
          .and_return(true)
      end

      it 'returns true' do
        expect(log.diagnostic_enabled?(described_class::CLINICAL_NOTES)).to be true
      end
    end

    context 'when domain toggle is off but global is on' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_allergies_diagnostic, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_diagnostic_logging, user)
          .and_return(true)
      end

      it 'returns true via global fallback' do
        expect(log.diagnostic_enabled?(described_class::ALLERGIES)).to be true
      end
    end

    context 'when both toggles are off' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_clinical_notes_diagnostic, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_diagnostic_logging, user)
          .and_return(false)
      end

      it 'returns false' do
        expect(log.diagnostic_enabled?(described_class::CLINICAL_NOTES)).to be false
      end
    end

    context 'when called without a resource' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medical_records_diagnostic_logging, user)
          .and_return(true)
      end

      it 'checks only the global toggle' do
        expect(log.diagnostic_enabled?).to be true
      end
    end

    context 'when no user' do
      let(:user) { nil }

      it 'returns false without checking Flipper' do
        expect(Flipper).not_to receive(:enabled?)
        expect(log.diagnostic_enabled?).to be false
      end
    end
  end

  describe 'PII stripping covers all declared keys' do
    it 'strips every key in PII_KEYS' do
      pii_hash = described_class::PII_KEYS.index_with { 'secret' }
      pii_hash[:safe_field] = 'visible'

      expect(Rails.logger).to receive(:info) do |payload|
        described_class::PII_KEYS.each do |key|
          expect(payload).not_to have_key(key), "Expected #{key} to be stripped but it was present"
        end
        expect(payload[:safe_field]).to eq('visible')
      end

      log.info(resource: 'test', action: 'test', **pii_hash)
    end

    it 'strips VA/DoD identifier keys' do
      expect(Rails.logger).to receive(:info) do |payload|
        %i[edipi birls_id participant_id sec_id vet360_id].each do |key|
          expect(payload).not_to have_key(key), "Expected #{key} to be stripped but it was present"
        end
        expect(payload[:safe_field]).to eq('visible')
      end

      log.info(resource: 'test', action: 'test',
               edipi: '1234567890', birls_id: '123456789',
               participant_id: '600000001', sec_id: '0000000001',
               vet360_id: '12345', safe_field: 'visible')
    end

    it 'strips authentication UUID keys' do
      expect(Rails.logger).to receive(:info) do |payload|
        %i[user_uuid idme_uuid logingov_uuid].each do |key|
          expect(payload).not_to have_key(key), "Expected #{key} to be stripped but it was present"
        end
      end

      log.info(resource: 'test', action: 'test',
               user_uuid: 'abc-123', idme_uuid: 'def-456', logingov_uuid: 'ghi-789')
    end
  end
end
