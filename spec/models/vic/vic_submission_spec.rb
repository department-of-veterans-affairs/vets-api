# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::VICSubmission, type: :model do
  describe '#update_state_to_completed' do
    it 'should set the state when then response is set' do
      submission = described_class.new
      submission.response = { foo: true}
      expect(submission.valid?).to eq(true)
      expect(submission.state).to eq('success')
    end
  end
end
