# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEventCreator do
  describe '#perform' do
    subject { described_class.perform }

    let(:config_file_path) { Rails.root.join('config', 'user_action_events.yml') }
    let(:user_action_event_configs) { YAML.load_file(config_file_path) }

    context 'when the event config file does not exist' do
      let(:expected_log_message) { 'UserActionEvents config file not found; skipping database population.' }

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
      context 'when the user action event does not exist' do
        let(:user_action_event_configs) { { some_identifier: { details:, event_type: } } }
        let(:details) { 'some details' }
        let(:event_type) { 'authentication' }

        before do
          allow(YAML).to receive(:load_file).and_return(user_action_event_configs)
        end

        it 'creates a new user action event' do
          expect { subject }.to change(UserActionEvent, :count).by(1)
          expect(UserActionEvent.last.identifier).to eq(user_action_event_configs.keys.last.to_s)
          expect(UserActionEvent.last.details).to eq(details)
          expect(UserActionEvent.last.event_type).to eq(event_type)
        end
      end

      context 'when the user action event already exists' do
        let(:details) { user_action_event_configs.values.last['details'] }
        let(:event_type) { user_action_event_configs.values.last['event_type'] }

        it 'updates the existing user action event' do
          expect { subject }.not_to change(UserActionEvent, :count)
          expect(UserActionEvent.last.details).to eq(details)
          expect(UserActionEvent.last.event_type).to eq(event_type)
        end
      end

      context 'when an error occurs' do
        let(:error_message) { 'some error message' }
        let(:expected_error_log) { "[UserActionEvent][Setup] Error loading user action event: #{error_message}" }

        before { allow(YAML).to receive(:load_file).and_raise(error_message) }

        it 'logs an error message' do
          expect(Rails.logger).to receive(:error).with(expected_error_log)
          subject
        end
      end
    end
  end
end
