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
    File.read('spec/support/disability_compensation_form/submissions/with_4142_2024.json')
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

  let(:file_path) { 'tmp/pdfs/mock_form_final.pdf' }

  describe '#initialize' do
    let(:mock_digest) { instance_double(Digest::SHA256, hexdigest: 'mocked_sha256_digest') }
    let(:mock_page)   { instance_double(PDF::Reader::Page) }
    let(:mock_reader) { instance_double(PDF::Reader, pages: Array.new(3, mock_page)) }

    before do
      allow(Flipper).to receive(:enabled?).with(:disability_526_form4142_validate_schema).and_return(false)

      # Mock expensive PDF operations to avoid file I/O
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(file_path)
      allow(Common::FileHelpers).to receive(:delete_file_if_exists)
      datestamp_instance = instance_double(PDFUtilities::DatestampPdf, run: file_path)
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_instance)
      allow(Faraday::UploadIO).to receive(:new).with(file_path, 'application/pdf')
      allow(Digest::SHA256).to receive(:file).with(file_path).and_return(mock_digest)
      allow(PDF::Reader).to receive(:new).with(file_path).and_return(mock_reader)
    end

    it 'initializes with submission and jid' do
      expected_provider_facility = form4142['providerFacility'].map do |facility|
        facility.merge('conditionsTreated' => facility['treatedDisabilityNames'].join(', '))
      end
      expected = form4142.clone.merge('providerFacility' => expected_provider_facility)
      expect(PdfFill::Filler).to receive(:fill_ancillary_form)
        .with(expected, submission.submitted_claim_id, '21-4142-2024')

      expect(processor.instance_variable_get(:@pdf_path)).to be_a(String)
      expect(processor.instance_variable_get(:@request_body)).to be_a(Hash)
    end

    it 'transforms provider facilities correctly' do
      transformed_data = processor.send(:transform_provider_facilities,
                                        JSON.parse(form_json)['form4142'])['providerFacility']

      expect(transformed_data.size).to eq(3)
      expect(transformed_data[0]['conditionsTreated']).to eq(
        'PTSD (post traumatic stress disorder), Coding Trauma, Nasal Trauma'
      )
      expect(transformed_data[1]['conditionsTreated']).to eq('Coding Trauma')
      expect(transformed_data[2]['conditionsTreated']).to eq(
        'PTSD (post traumatic stress disorder), Coding Trauma, Nasal Trauma'
      )
    end

    it 'handles empty provider facilities' do
      empty_form_json = JSON.parse(form_json)
      empty_form_json['form4142']['providerFacility'] = []

      transformed_data = processor.send(:transform_provider_facilities, empty_form_json)['form4142']['providerFacility']

      expect(transformed_data).to eq([])
    end

    it 'handles missing providerFacility key' do
      form_without_facilities = JSON.parse(form_json)
      form_without_facilities['form4142'].delete('providerFacility')

      transformed_data = processor.send(:transform_provider_facilities,
                                        form_without_facilities)['form4142']['providerFacility']

      expect(transformed_data).to be_nil
    end

    it 'preserves other form data during transformation' do
      original_data = JSON.parse(form_json)
      transformed_data = processor.send(:transform_provider_facilities, original_data)

      # Verify non-providerFacility data is preserved
      expect(transformed_data.except('providerFacility'))
        .to eq(original_data.except('providerFacility'))
    end

    context 'when feature flag is disabled on the frontend' do
      let(:legacy_form_json) { File.read('spec/support/disability_compensation_form/submissions/with_4142.json') }
      let(:legacy_processor) { described_class.new(submission_with_legacy4142, jid) }
      let(:legacy_received_date) do
        submission_with_legacy4142.created_at.in_time_zone('Central Time (US & Canada)')
      end
      let(:submission_with_legacy4142) do
        create(:form526_submission,
               user_uuid: user.uuid,
               auth_headers_json: auth_headers.to_json,
               saved_claim_id: saved_claim2.id,
               form_json: legacy_form_json,
               submitted_claim_id: 2)
      end
      let(:saved_claim2) { create(:va526ez) }
      let(:legacy_form4142) do
        JSON.parse(legacy_form_json)['form4142']
            .merge({ 'signatureDate' => legacy_received_date.strftime('%Y-%m-%d %H:%M:%S') })
      end

      before do
        allow(PdfFill::Filler).to receive(:fill_form).and_return(file_path)
      end

      it 'parses frontend submission data and uses the legacy template' do
        Timecop.freeze(legacy_received_date) do
          expect(PdfFill::Filler).to receive(:fill_ancillary_form)
            .with(legacy_form4142, submission_with_legacy4142.submitted_claim_id, '21-4142')

          expect(legacy_processor.instance_variable_get(:@submission)).to eq(submission_with_legacy4142)
          expect(legacy_processor.instance_variable_get(:@pdf_path)).to be_a(String)
          expect(legacy_processor.instance_variable_get(:@request_body)).to be_a(Hash)
        end
      end
    end

    context 'error handling' do
      it 'handles PDF generation errors gracefully' do
        allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF error')

        expect { described_class.new(submission, jid) }.to raise_error(StandardError, 'PDF error')
      end

      it 'handles malformed JSON input' do
        malformed_submission = submission.dup
        malformed_submission.form_json = '{"invalid": json}'

        expect { described_class.new(malformed_submission, jid) }.to raise_error(JSON::ParserError)
      end
    end
  end
end
