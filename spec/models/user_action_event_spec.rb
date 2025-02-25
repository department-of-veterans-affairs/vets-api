# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEvent, type: :model do
  describe 'validations' do
    subject { create(:user_action_event, event_type:) }

    let(:expected_event_types) { %w[authentication] }
    let(:event_type) { expected_event_types.sample }

    it { is_expected.to validate_presence_of(:details) }
    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_uniqueness_of(:identifier) }
    it { is_expected.to validate_presence_of(:event_type) }

    context 'when validating inclusion of event_type' do
      context 'when the event_type is valid' do
        it { is_expected.to allow_value(event_type).for(:event_type) }
      end

      context 'when the event_type is invalid' do
        let(:event_type) { 'some-invalid-event_type' }
        let(:expected_error_message) { 'Validation failed: Event type is not included in the list' }

        it 'raises a validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end

    it { is_expected.to have_many(:user_actions).dependent(:restrict_with_exception) }
  end
end
