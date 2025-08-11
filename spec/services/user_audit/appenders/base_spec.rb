# frozen_string_literal: true

require 'rails_helper'

class SomeAppender < UserAudit::Appenders::Base
  def append_log; end
end

class IncompleteAppender < UserAudit::Appenders::Base; end

RSpec.describe UserAudit::Appenders::Base do
  subject(:appender) { SomeAppender.new }

  let(:identifier) { :some_event }
  let(:status) { 'success' }
  let(:subject_user_verification) { create(:user_verification) }
  let(:acting_user_verification) { create(:user_verification) }
  let(:user_action_event) { create(:user_action_event, identifier:) }

  let(:named_tags) do
    { remote_ip: Faker::Internet.ip_v4_address, user_agent: Faker::Internet.user_agent }
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
    double(
      SemanticLogger::Log,
      payload:,
      named_tags:,
      time: Time.zone.now,
      level: :info,
      level_index: 2,
      name: 'UserAudit',
      metric_only?: false
    )
  end

  before do
    allow(Rails.logger).to receive(:info)
  end

  describe '#should_log?' do
    context 'when all required keys are present' do
      it 'returns true' do
        expect(appender).to be_should_log(log)
      end
    end

    context 'when a required key is missing' do
      let(:subject_user_verification) { nil }
      let(:expected_log_message) { '[UserAudit][Logger] error: Missing required log payload keys: user_verification' }
      let(:expected_log_payload) do
        {
          audit_log: {
            log_payload: {
              event: identifier,
              status:,
              acting_user_verification_id: acting_user_verification&.id
            },
            log_tags: named_tags
          },
          error_message: nil,
          appender: appender.class.name
        }
      end

      it 'logs an error and returns false' do
        expect(appender).not_to be_should_log(log)
        expect(Rails.logger).to have_received(:info).with(expected_log_message, **expected_log_payload)
      end
    end
  end

  describe '#log' do
    context 'when append_log is not implemented' do
      subject(:incomplete_appender) { IncompleteAppender.new }

      let(:expected_log_message) { 'Subclasses must implement #append_log' }

      it 'raises a NotImplementedError' do
        expect { incomplete_appender.log(log) }
          .to raise_error(NotImplementedError, expected_log_message)
      end
    end

    context 'when an error occurs during log creation' do
      let(:exception_message) { 'append failure' }
      let(:expected_log_message) { '[UserAudit][Logger] error: Error appending log' }
      let(:expected_log_payload) do
        {
          audit_log: {
            log_payload: {
              user_verification_id: subject_user_verification.id,
              event: identifier,
              status:,
              acting_user_verification_id: acting_user_verification&.id
            }, log_tags: named_tags
          },
          error_message: exception_message,
          appender: appender.class.name
        }
      end

      before do
        allow(appender).to receive(:append_log).and_raise(StandardError, exception_message) # rubocop:disable RSpec/SubjectStub
      end

      it 'logs the error message' do
        appender.log(log)
        expect(Rails.logger).to have_received(:info).with(expected_log_message, **expected_log_payload)
      end
    end

    context 'when acting_user_verification is not provided' do
      let(:acting_user_verification) { nil }

      it 'defaults acting_user_verification to subject_user_verification' do
        appender.log(log)

        expect(appender.send(:acting_user_verification)).to eq(subject_user_verification)
      end
    end
  end
end
