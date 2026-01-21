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

  let(:saved_claim) { create(:va526ez) }
  let(:submission) do
    create(:form526_submission,
           user_uuid: user.uuid,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id,
           form_json:,
           submitted_claim_id: 1)
  end
  let(:jid) { '123456789' }
  let(:processor) { described_class.new(submission, jid) }
  let(:received_date) { submission.created_at.in_time_zone('Central Time (US & Canada)').strftime('%Y-%m-%d %H:%M:%S') }
  let(:form4142) { JSON.parse(form_json)['form4142'].merge({ 'signatureDate' => received_date }) }

  describe '#initialize' do
    it 'initializes with submission and jid' do
      expect(PdfFill::Filler).to receive(:fill_ancillary_form)
        .and_call_original
        .once
        .with(form4142, submission.submitted_claim_id, '21-4142')

      expect(processor.instance_variable_get(:@submission)).to eq(submission)
      expect(processor.instance_variable_get(:@pdf_path)).to be_a(String)
      expect(processor.instance_variable_get(:@request_body)).to be_a(Hash)
    end
  end
end
