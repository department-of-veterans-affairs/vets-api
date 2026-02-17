# frozen_string_literal: true

require 'rails_helper'

# Tests for Lighthouse::Form526ClaimPdfCheck job
#
# Verifies that the job correctly checks for Form 526 PDF presence in
# Lighthouse claims and logs the appropriate results.
RSpec.describe Lighthouse::Form526ClaimPdfCheck, type: :job do
  let(:submission) { create(:form526_submission, submitted_claim_id: 123_456) }
  let(:service) { double('BenefitsClaims::Service') }
  let(:response_body) do
    {
      'data' => {
        'attributes' => {
          'supportingDocuments' => [
            { 'documentTypeLabel' => 'VA 21-526 Veterans Application for Compensation or Pension' }
          ]
        }
      }
    }
  end

  before do
    allow(BenefitsClaims::Service).to receive(:new).and_return(service)
    allow(service).to receive(:get_claim).and_return(response_body)
  end

  describe '#perform' do
    it 'logs the result when PDF is found' do
      expect(Rails.logger).to receive(:info).with(
        'Form526ClaimPdfCheck result',
        {
          form526_submission_id: submission.id,
          submitted_claim_id: 123_456,
          has_pdf_in_claim: true
        }
      )

      described_class.new.perform(submission.id)
    end

    it 'logs the result when PDF is not found' do
      allow(service).to receive(:get_claim).and_return(
        {
          'data' => {
            'attributes' => {
              'supportingDocuments' => [
                { 'documentTypeLabel' => 'Some other document' }
              ]
            }
          }
        }
      )

      expect(Rails.logger).to receive(:info).with(
        'Form526ClaimPdfCheck result',
        {
          form526_submission_id: submission.id,
          submitted_claim_id: 123_456,
          has_pdf_in_claim: false
        }
      )

      described_class.new.perform(submission.id)
    end
  end
end
