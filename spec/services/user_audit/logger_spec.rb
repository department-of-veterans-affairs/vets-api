# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAudit::Logger do
  describe '#initialize' do
    subject { described_class.new }

    it { is_expected.to be_a(SemanticLogger::Logger) }
  end

  describe 'status methods' do
    let(:logger) { described_class.new }
    let(:expected_status_methods) { %w[initial success error] }

    it 'defines status methods' do
      expected_status_methods.each do |status|
        expect(logger).to respond_to(status)
      end
    end
  end

  describe '#initial' do
    let(:logger) { described_class.new }

    it 'logs with the correct level' do
      expect(logger).to receive(:info).with(status: 'initial')
      logger.initial
    end
  end

  describe '#success' do
    let(:logger) { described_class.new }

    it 'logs with the correct level' do
      expect(logger).to receive(:info).with(status: 'success')
      logger.success
    end
  end

  describe '#error' do
    let(:logger) { described_class.new }

    it 'logs with the correct level' do
      expect(logger).to receive(:info).with(status: 'error')
      logger.error
    end
  end

  context 'when the appenders are appended' do
    let(:logger) { described_class.new }

    before do
      SemanticLogger.add_appender(appender: UserAudit::Appenders::AuditLogAppender.new, async: false)
      SemanticLogger.add_appender(appender: UserAudit::Appenders::UserActionAppender.new, async: false)
    end

    it 'create an Audit::Log record' do
      expect { logger.initial }.to change(Audit::Log, :count).by(1)

      audit_log = Audit::Log.last

      expect(audit_log.subject_user_identifier).to eq(subject_user_verification.user_account.icn)
      expect(audit_log.subject_user_identifier_type).to eq('icn')
      expect(audit_log.acting_user_identifier).to eq(acting_user_verification.user_account.icn)
    end
  end
end
