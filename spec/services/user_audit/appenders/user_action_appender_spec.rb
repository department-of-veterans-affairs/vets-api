# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAudit::Appenders::UserActionAppender do
  subject(:appender) { described_class.new }

  let(:identifier) { 'event-1' }
  let(:status)     { 'success' }
  let!(:subject_user_verification) { create(:user_verification) }
  let!(:acting_user_verification)  { create(:user_verification) }
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
      it 'creates a UserAction record' do
        expect { appender.log(log) }
          .to change(UserAction, :count).by(1)

        user_action = UserAction.last

        expect(user_action.user_action_event_id).to eq(user_action_event.id)
        expect(user_action.subject_user_verification_id).to eq(subject_user_verification.id)
        expect(user_action.acting_user_verification_id).to eq(acting_user_verification.id)
        expect(user_action.status).to eq(status)
        expect(user_action.acting_ip_address).to eq(named_tags[:ip])
        expect(user_action.acting_user_agent).to eq(named_tags[:user_agent])

        expect(Rails.logger).to have_received(:info).with(
          '[UserAudit][Logger] User action created',
          event_id: user_action_event.id,
          event_description: user_action_event.details,
          status:,
          user_action: user_action.id
        )
      end

      context 'when acting_user_verification is not provided' do
        let(:acting_user_verification) { nil }

        it 'defaults acting_user_verification to subject_user_verification' do
          appender.log(log)

          user_action = UserAction.last
          expect(user_action.acting_user_verification_id).to eq(subject_user_verification.id)
        end
      end
    end

    context 'when an error occurs during log creation' do
      before do
        allow(UserAction).to receive(:create!).and_raise(StandardError, 'Database error')
      end

      it 'logs an error' do
        appender.log(log)

        expect(Rails.logger).to have_received(:error).with(
          "#{appender.class.name} error: Error appending log",
          audit_log: { log_payload: payload, log_tags: named_tags },
          error_message: 'Database error'
        )
      end
    end
  end
end
