# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GIBillFeedbackSubmissionJob do
  let(:gi_bill_feedback) { create(:gi_bill_feedback) }

  describe '#perform' do
    before do
      expect_any_instance_of(GIBillFeedback).to receive(:transform_form).and_return({})
    end

    context 'with a valid submission' do
      it 'updates the gi bill feedback model' do
        expect_any_instance_of(Gibft::Service).to receive(:submit).with(
          {}
        ).and_return(case_id: 'case_id')
        described_class.new.perform(gi_bill_feedback.guid, {}, nil)

        updated_feedback = GIBillFeedback.find(gi_bill_feedback.guid)
        expect(updated_feedback.state).to eq('success')
        expect(updated_feedback.parsed_response).to eq('case_id' => 'case_id')
      end
    end

    context 'when the service has an error' do
      it 'sets the submission to failed' do
        expect_any_instance_of(Gibft::Service).to receive(:submit).and_raise('foo')
        expect do
          described_class.new.perform(gi_bill_feedback.guid, {}, nil)
        end.to raise_error('foo')
        updated_feedback = GIBillFeedback.find(gi_bill_feedback.guid)

        expect(updated_feedback.state).to eq('failed')
      end
    end
  end
end
