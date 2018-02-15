# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::SubmissionJob do
  let(:uuid) { 'fab2eea7-982e-4171-a2cb-8e9455ab00ed' }
  let(:user) { create(:user, :loa3) }

  describe '#perform' do
    it 'should update the vic submission response' do
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
      vic_submission = build(:vic_submission)
      vic_submission.user_uuid = user.uuid
      expect(User).to receive(:find).with(user.uuid).and_return(user)
      expect_any_instance_of(VIC::Service).to receive(:submit).with(
        JSON.parse(vic_submission.form), user
      ).and_return(case_id: uuid)
      vic_submission.save!
      described_class.drain
      vic_submission.reload

      expect(vic_submission.state).to eq('success')
      expect(vic_submission.response).to eq(
        'case_id' => uuid
      )
    end

    it 'should set the submission to failed if it doesnt work' do
      vic_submission = create(:vic_submission)
      expect_any_instance_of(VIC::Service).to receive(:submit).and_raise('foo')
      expect do
        described_class.drain
      end.to raise_error('foo')
      vic_submission.reload

      expect(vic_submission.state).to eq('failed')
    end
  end
end
