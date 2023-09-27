# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/ews_vbms_sidekiq'

RSpec.describe ClaimsApi::EwsVBMSSidekiq do
  let(:dummy_class) { Class.new { extend ClaimsApi::EwsVBMSSidekiq } }

  describe 'upload_to_vbms' do
    let(:evidence_waiver_submission) { create(:claims_api_evidence_waiver_submission) }

    context 'when upload is successful' do
      it 'updates the Evidence Waiver Submission record' do
        allow_any_instance_of(ClaimsApi::LocalBGS).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload!).and_return(
          {
            status: ClaimsApi::EvidenceWaiverSubmission::UPLOADED
          }
        )

        dummy_class.upload_to_vbms(evidence_waiver_submission, '/some/random/path')
        evidence_waiver_submission.reload

        expect(evidence_waiver_submission.status).to eq(ClaimsApi::EvidenceWaiverSubmission::UPLOADED)
      end
    end
  end
end
