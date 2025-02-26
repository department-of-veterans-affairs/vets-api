# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEventCreator do
  describe '#perform' do
    subject { described_class.perform }

    context 'when the event config file does not exist' do
      let(:expected_log_message) { '[UserActionEventCreator] Config file not found; skipping database population.' }

      before { allow(File).to receive(:exist?).and_return(false) }

      it 'does not create any user action events' do
        expect { subject }.not_to change(UserActionEvent, :count)
      end

      it 'logs a message' do
        expect(Rails.logger).to receive(:info).with(expected_log_message)
        subject
      end
    end

    context 'when the event config file exists' do
      let(:identifier) { 'some_identifier' }
      let(:user_action_event_configs) { { identifier => { details:, event_type: } } }
      let(:details) { 'some-details' }
      let(:event_type) { 'some-event_type' }

      before { allow(YAML).to receive(:load_file).and_return(user_action_event_configs) }

      context 'when the user action event does not exist' do
        it 'creates a new user action event' do
          expect { subject }.to change(UserActionEvent, :count).by(1)
          expect(UserActionEvent.last.identifier).to eq('some_identifier')
          expect(UserActionEvent.last.details).to eq(details)
          expect(UserActionEvent.last.event_type).to eq(event_type)
        end
      end

      context 'when the user action event already exists' do
        before { create(:user_action_event, identifier:, details: 'old-details', event_type: 'old-event_type') }

        it 'updates the existing user action event' do
          expect { subject }.not_to change(UserActionEvent, :count)
          expect(UserActionEvent.last.identifier).to eq(identifier)
          expect(UserActionEvent.last.details).to eq(details)
          expect(UserActionEvent.last.event_type).to eq(event_type)
        end
      end

      context 'when an error occurs' do
        let(:error_message) { 'some error message' }
        let(:expected_error_log) { "[UserActionEventCreator] Error loading user action event: #{error_message}" }

        before { allow(YAML).to receive(:load_file).and_raise(error_message) }

        it 'logs an error message' do
          expect(Rails.logger).to receive(:error).with(expected_error_log)
          subject
        end
      end
    end
  end
end
