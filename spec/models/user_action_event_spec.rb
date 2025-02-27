# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEvent, type: :model do
  describe 'validations' do
    subject { create(:user_action_event) }

    it { is_expected.to validate_presence_of(:details) }
    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_uniqueness_of(:identifier) }
    it { is_expected.to validate_presence_of(:event_type) }

    it { is_expected.to have_many(:user_actions).dependent(:restrict_with_exception) }
  end

  describe '.setup' do
    subject { described_class.setup }

    context 'when the event config file does not exist' do
      let(:expected_error) do
        '[UserActionEvent][Setup] Error: Config file not found'
      end

      before do
        allow(Rails.root).to receive(:join).with('config', 'user_action_events.yml').and_return('some-path.yml')
      end

      it 'raises an error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'when the event config file exists' do
      let(:user_action_events_yaml) { YAML.load_file('spec/fixtures/user_audit/user_action_events.yml') }
      let(:identifier) { user_action_events_yaml.keys.last }
      let(:details) { user_action_events_yaml[identifier]['details'] }
      let(:event_type) { user_action_events_yaml[identifier]['event_type'] }

      before { allow(YAML).to receive(:load_file).and_return(user_action_events_yaml) }

      context 'when the user action event does not exist' do
        it 'creates a new user action event' do
          expect { subject }.to change(UserActionEvent, :count).by(1)
          user_action_event = UserActionEvent.last

          expect(user_action_event.identifier).to eq(identifier)
          expect(user_action_event.details).to eq(details)
          expect(user_action_event.event_type).to eq(event_type)
        end
      end

      context 'when the user action event already exists' do
        let!(:existing_event) do
          create(:user_action_event, identifier:, details: old_details, event_type: old_event_type)
        end

        context 'when the user action event attributes are different from the event_config' do
          let(:old_details) { 'old-details' }
          let(:old_event_type) { 'old-event_type' }

          it 'updates the existing user action event' do
            expect { subject }.not_to change(UserActionEvent, :count)
            user_action_event = UserActionEvent.last

            expect(user_action_event.identifier).to eq(existing_event.identifier)
            expect(user_action_event.details).to eq(details)
            expect(user_action_event.event_type).to eq(event_type)
          end
        end

        context 'when the user action event attributes are the same as the event_config' do
          let(:old_details) { details }
          let(:old_event_type) { event_type }

          it 'does not update the existing user action event' do
            expect { subject }.not_to change(UserActionEvent, :count)
            user_action_event = UserActionEvent.last

            expect(user_action_event.attributes).to match(existing_event.attributes)
          end
        end
      end

      context 'when an error occurs' do
        let(:error_message) { 'some error message' }
        let(:expected_error_log) { "[UserActionEvent][Setup] Error: #{error_message}" }

        before { allow(YAML).to receive(:load_file).and_raise(error_message) }

        it 'raises an error' do
          expect { subject }.to raise_error(expected_error_log)
        end
      end
    end
  end
end
