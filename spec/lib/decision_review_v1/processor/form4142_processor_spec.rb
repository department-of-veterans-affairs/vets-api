# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/utilities/form_4142_processor'

describe DecisionReviewV1::Processor::Form4142Processor do
  let(:user) { build(:disabilities_compensation_user) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
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
  let(:processor) { described_class.new(form_data: submission.form['form4142'], submission_id: submission.id) }
  let(:received_date) { submission.created_at.in_time_zone('Central Time (US & Canada)').strftime('%Y-%m-%d %H:%M:%S') }
  let(:form4142) { JSON.parse(form_json)['form4142'].merge({ 'signatureDate' => received_date }) }

  describe '#initialize' do
    it 'initializes with submission and jid' do
      expect(PdfFill::Filler).to receive(:fill_ancillary_form)
        .and_call_original
        .once
        .with(form4142, anything, '21-4142')
      # Note on the expectation: #anything is a special keyword that matches any argument.
      # We used it here since the uuid is created at runtime.

      expect(processor.instance_variable_get(:@submission)).to eq(submission)
      expect(processor.instance_variable_get(:@pdf_path)).to be_a(String)
      expect(processor.instance_variable_get(:@request_body)).to be_a(Hash)
    end
  end

  context 'setting a correct signed-at date' do
    context 'when a submission was created more than a day before processing' do
      let!(:created_at) { 6.months.ago.in_time_zone(described_class::TIMEZONE) }

      it 'sets the signed at date to the date of submission creation' do
        Timecop.freeze(created_at) { submission }

        key = described_class::SIGNATURE_DATE_KEY
        time_format = described_class::SIGNATURE_TIMESTAMP_FORMAT
        sig_dat = processor.instance_variable_get('@form')[key]
        expect(sig_dat).to eq(created_at.strftime(time_format))
      end
    end
  end
end
