# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form4142_processor'
require 'evss/disability_compensation_auth_headers' # required to build a Form526Submission


describe EVSS::DisabilityCompensationForm::Form4142Processor do
  let(:user) { build(:disabilities_compensation_user) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:evss_claim_id) { 123_456_789 }
  let(:form_json) do
    File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
  end

  # let(:saved_claim) { FactoryBot.create(:va526ez) }
  # let(:submission) do
  #   create(:form526_submission,
  #          user_uuid: user.uuid,
  #          auth_headers_json: auth_headers.to_json,
  #          saved_claim_id: saved_claim.id)
  # end
  # let(:submission) do
  #   Form526Submission.create(user_uuid: user.uuid,
  #                            auth_headers_json: auth_headers.to_json,
  #                            saved_claim_id: saved_claim.id,
  #                            form_json:,
  #                            submitted_claim_id: evss_claim_id)
  # end
  let(:jid) { '123456789' }
  let(:processor) { described_class.new(submission, jid) }

  # describe '#initialize' do
  #   it 'initializes with submission and jid' do
  #     expect(processor.instance_variable_get(:@submission)).to eq(submission)
  #     expect(processor.instance_variable_get(:@pdf_path)).to be_a(String)
  #     expect(processor.instance_variable_get(:@request_body)).to be_a(Hash)
  #   end
  # end

  describe '#generate_stamp_pdf' do
    let(:saved_claim) {
      SavedClaim::DisabilityCompensation::Form526AllClaim.create!(form:
        JSON.parse(File.read('spec/support/disability_compensation_form/all_claims_fe_submission.json'))['form526'].to_json)
    }
    let(:submission) do
      create(:form526_submission,
             user_uuid: user.uuid,
             auth_headers_json: auth_headers.to_json,
             saved_claim_id: saved_claim.id)
    end
    let(:received_date) {submission.created_at.in_time_zone('Central Time (US & Canada)').strftime('%Y-%m-%d %H:%M:%S')}
    let(:form4142) { form_json.merge({ signatureDate: received_date })}

    it 'generates stamped PDF path' do
      # expect(EVSSClaimDocument)
      #   .to receive(:new)
      #         .with(
      #           evss_claim_id: submission.submitted_claim_id,
      #           file_name: 'BDD_Instructions.pdf',
      #           tracked_item_id: nil,
      #           document_type: 'L023'
      #         )
      #         .and_return(document_data)
      #
      # subject.perform_async(submission.id)
      # expect(client).to receive(:upload).with(file_read, document_data)
      # described_class.drain


      # want to test that form4142 has signatureDate (first argument for fill_ancillary_form)
      # want to test that timestamp is @submission.created_at.in_time_zone('Central Time (US & Canada)')
      debugger
      # allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return('stamped_pdf_path')

      expect(PdfFill::Filler).to have_received(:fill_ancillary_form).with(form4142, submission.submitted_claim_id, '21-4142')

      # allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return('pdf_content')
      # allow(CentralMail::DatestampPdf).to receive(:new).and_return(double('DatestampPdf', run: { text: 'VA.gov', x: 5, y: 5,
                                                                                                 # timestamp: submission.created_at }))

      stamped_path = processor.send(:generate_stamp_pdf)

      expect(stamped_path).to eq('stamped_pdf_path')
    end
  end
end
