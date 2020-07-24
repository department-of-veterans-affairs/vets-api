# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::SubmitDependentsPDFJob do
  let(:gi_bill_feedback) { create(:gi_bill_feedback) }
  let(:claim) { double('claim') }
  let(:dependency_claim) { create(:dependency_claim_no_vet_information) }
  let(:vet_info) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => '796043735',
        'va_file_number' => '796043735'
      }
    }
  end

  before { allow(claim).to receive(:id).and_return('686C-674') }

  describe '#perform' do
    context 'with a valid submission' do
      it 'creates a PDF' do
        expect_any_instance_of(VBMS::SubmitDependentsPDFJob).to receive(:to_pdf).with(
          dependency_claim, vet_info
        )

        described_class.new.perform(dependency_claim.id, vet_info)
      end
    end

    # context 'when the service has an error' do
    #   it 'sets the submission to failed' do
    #     expect_any_instance_of(Gibft::Service).to receive(:submit).and_raise('foo')
    #     expect do
    #       described_class.new.perform(gi_bill_feedback.guid, {}, nil)
    #     end.to raise_error('foo')
    #     updated_feedback = GIBillFeedback.find(gi_bill_feedback.guid)
    #
    #     expect(updated_feedback.state).to eq('failed')
    #   end
    # end
  end
end
