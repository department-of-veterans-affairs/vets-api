# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::SubmissionJob do
  let(:uuid) { 'fab2eea7-982e-4171-a2cb-8e9455ab00ed' }

  describe '#perform' do
    it 'should update the vic submission response' do
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
      vic_submission = create(:vic_submission)
      described_class.drain
      vic_submission.reload

      expect(vic_submission.state).to eq('success')
      expect(vic_submission.response).to eq(
        'confirmation_number' => uuid
      )
    end
  end
end
