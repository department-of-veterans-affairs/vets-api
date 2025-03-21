# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAudit do
  describe '.logger' do
    subject(:logger) { described_class.logger }

    it 'returns an instance of UserAudit::Logger' do
      expect(logger).to be_a(UserAudit::Logger)
    end

    it 'appends the the appenders to SemanticLogger' do
      logger

      expect(SemanticLogger.appenders).to include(UserAudit::Appenders::AuditLogAppender)
      expect(SemanticLogger.appenders).to include(UserAudit::Appenders::UserActionAppender)
    end

    context 'when logger calls a status method' do
      let(:identifier) { 'event-1' }
      let(:status)     { 'success' }
      let!(:subject_user_verification) { create(:user_verification) }
      let!(:user_action_event) { create(:user_action_event, identifier:) }

      let(:named_tags) do
        { ip: Faker::Internet.ip_v4_address, user_agent: Faker::Internet.user_agent }
      end

      it 'calls the appended appenders' do
        logger.initial(event: 'event-1', user_verification: subject_user_verification)
        SemanticLogger.flush
        expect(UserAction.count).to eq(1)
        expect(Audit::Log.count).to eq(1)

        audit_log = Audit::Log.last

        expect(audit_log.subject_user_identifier).to eq(subject_user_verification.user_account.icn)
        expect(audit_log.subject_user_identifier_type).to eq('icn')
        expect(audit_log.acting_user_identifier).to eq(subject_user_verification.user_account.icn)
        expect(audit_log.acting_user_identifier_type).to eq('icn')

        user_action = UserAction.last
        expect(user_action.user_action_event_id).to eq(user_action_event.id)
        expect(user_action.subject_user_verification_id).to eq(subject_user_verification.id)
        expect(user_action.acting_user_verification_id).to eq(subject_user_verification.id)
        expect(user_action.status).to eq(status)
        expect(user_action.acting_ip_address).to eq(named_tags[:ip])
        expect(user_action.acting_user_agent).to eq(named_tags[:user_agent])
        expect(user_action.user_action_event.identifier).to eq(identifier)
        expect(user_action.user_action_event.details).to eq(user_action_event.details)
      end
    end
  end
end
