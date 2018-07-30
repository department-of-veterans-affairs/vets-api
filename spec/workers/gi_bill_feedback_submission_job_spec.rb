# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GIBillFeedbackSubmissionJob do
  let(:gi_bill_feedback) { create(:gi_bill_feedback) }

  describe '#perform' do
    context 'with a valid submission' do
      before do
        expect_any_instance_of(Gibft::Service).to receive(:submit).with(
          {}
        ).and_return(case_id: 'case_id')
      end

      it 'should update the gi bill feedback model' do
        described_class.new.perform(gi_bill_feedback.guid, {})

        updated_feedback = GIBillFeedback.find(gi_bill_feedback.guid)
        expect(updated_feedback.state).to eq('success')
        expect(updated_feedback.parsed_response).to eq({"case_id"=>"case_id"})
      end
    end

    context 'when the service has an error' do
      it 'should set the submission to failed' do
        vic_submission = create(:vic_submission)
        ProcessFileJob.drain
        expect_any_instance_of(VIC::Service).to receive(:submit).and_raise('foo')
        expect do
          described_class.drain
        end.to raise_error('foo')
        vic_submission.reload

        expect(vic_submission.state).to eq('failed')
      end
    end
  end
end
