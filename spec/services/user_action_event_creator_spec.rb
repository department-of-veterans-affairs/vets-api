# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEventCreator do
  describe '#perform' do
    subject { described_class.new(event_name:, event_config:).perform }

    let(:event_name) { 'some-event_name' }
    let(:event_config) do
      {
        'details' => details,
        'identifier' => identifier,
        'event_type' => event_type
      }
    end
    let(:details) { 'some-details' }
    let(:identifier) { 'some-identifier' }
    let(:event_type) { 'authentication' }

    context 'when validating the event config' do
      shared_examples 'error logging' do
        it 'logs an error message' do
          expect { subject }.to raise_error(StandardError, expected_error_message)
        end
      end

      context 'when the event config is missing details' do
        let(:details) { nil }
        let(:expected_error_message) { 'Event some-identifier is missing details' }

        it_behaves_like 'error logging'
      end

      context 'when the event config is missing an identifier' do
        let(:identifier) { nil }
        let(:expected_error_message) { 'Event some-event_name is missing an identifier' }

        it_behaves_like 'error logging'
      end

      context 'when the event config is missing an event_type' do
        let(:event_type) { nil }
        let(:expected_error_message) { 'Event some-identifier is missing an event_type' }

        it_behaves_like 'error logging'
      end

      context 'when the event config has an invalid event_type' do
        let(:event_type) { 'some-invalid-event_type' }
        let(:expected_error_message) { 'Event some-identifier has an invalid event_type' }

        it_behaves_like 'error logging'
      end
    end

    context 'when the event config is valid' do
      context 'when the user action event does not exist' do
        it 'creates a new user action event' do
          expect { subject }.to change(UserActionEvent, :count).by(1)
          expect(UserActionEvent.last.details).to eq(details)
          expect(UserActionEvent.last.event_type).to eq(event_type)
        end
      end

      context 'when the user action event already exists' do
        before { UserActionEvent.create!(identifier:, details: 'old-details', event_type: 'old-event_type') }

        it 'updates the existing user action event' do
          expect { subject }.not_to change(UserActionEvent, :count)
          expect(UserActionEvent.last.details).to eq(details)
          expect(UserActionEvent.last.event_type).to eq(event_type)
        end
      end
    end
  end
end
