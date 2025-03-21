# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAudit::Appenders::AuditLogAppender do
  subject(:appender) { described_class.new }

  let(:identifier) { 'event-1' }
  let(:status)     { 'success' }

  let(:subject_user_icn) { Faker::Number.number(digits: 10) }
  let(:acting_user_icn)  { Faker::Number.number(digits: 10) }

  let!(:subject_user_account) { create(:user_account, icn: subject_user_icn) }
  let!(:acting_user_account)  { create(:user_account, icn: acting_user_icn) }

  let!(:subject_user_verification) { create(:user_verification, user_account: subject_user_account) }
  let!(:acting_user_verification)  { create(:user_verification, user_account: acting_user_account) }
  let!(:user_action_event)         { create(:user_action_event, identifier:) }

  let(:named_tags) do
    { ip: Faker::Internet.ip_v4_address, user_agent: Faker::Internet.user_agent }
  end

  let(:payload) do
    {
      event: identifier,
      status:,
      user_verification: subject_user_verification,
      acting_user_verification:
    }.compact
  end

  let(:log) do
    double(SemanticLogger::Log,
           payload:,
           named_tags:,
           time: Time.zone.now,
           level: :info,
           level_index: 2,
           name: 'UserAudit',
           metric_only?: false)
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#log' do
    context 'when all required keys are present' do
      it 'creates an Audit::Log record' do
        expect { appender.log(log) }
          .to change(Audit::Log, :count).by(1)

        audit_log = Audit::Log.last

        expect(audit_log.subject_user_identifier).to eq(subject_user_verification.user_account.icn)
        expect(audit_log.subject_user_identifier_type).to eq('icn')
        expect(audit_log.acting_user_identifier).to eq(acting_user_verification.user_account.icn)
        expect(audit_log.acting_user_identifier_type).to eq('icn')
        expect(audit_log.event_id).to eq(user_action_event.identifier)
        expect(audit_log.event_description).to eq(user_action_event.details)
        expect(audit_log.event_status).to eq(status)
        expect(audit_log.event_occurred_at.to_i).to eq(log.time.to_i)
        expect(audit_log.message).to include(payload.merge(named_tags).as_json)

        expect(Rails.logger).to have_received(:info).with(
          '[UserAudit][Logger] Audit log created',
          event_id: user_action_event.id,
          event_description: user_action_event.details,
          status:,
          audit_log: audit_log.id
        )
      end

      context 'when acting_user_verification is not provided' do
        let(:acting_user_verification) { nil }

        it 'defaults acting_user_identifier to the subject user identifier' do
          appender.log(log)

          audit_log = Audit::Log.last
          expect(audit_log.acting_user_identifier).to eq(subject_user_verification.user_account.icn)
          expect(audit_log.acting_user_identifier_type).to eq('icn')
        end
      end

      context 'when user_account does not have an icn' do
        let(:subject_user_icn) { nil }
        let(:acting_user_icn)  { nil }

        it 'uses the user_verification credential_identifier for the user identifier' do
          appender.log(log)

          audit_log = Audit::Log.last
          expect(audit_log.subject_user_identifier).to eq(subject_user_verification.credential_identifier)
          expect(audit_log.subject_user_identifier_type).to eq('idme_uuid')
          expect(audit_log.acting_user_identifier).to eq(acting_user_verification.credential_identifier)
          expect(audit_log.acting_user_identifier_type).to eq('idme_uuid')
        end
      end
    end

    context 'when an error occurs during log creation' do
      before do
        allow(Audit::Log).to receive(:create!).and_raise(StandardError, 'Database error')
      end

      it 'logs an error' do
        appender.log(log)

        expect(Rails.logger).to have_received(:error).with(
          "#{appender.class.name} error: Error appending log",
          audit_log: { log_payload: payload, log_tags: named_tags },
          error_message: 'Database error'
        )
      end

      it 'does not create an Audit::Log record' do
        expect { appender.log(log) }.not_to change(Audit::Log, :count)
      end
    end
  end
end
