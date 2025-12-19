# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/lib/decision_reviews/pdf_template_stamper'
require './modules/decision_reviews/lib/decision_reviews/v1/service'
require './modules/decision_reviews/lib/decision_reviews/notification_email_to_pdf_service'

RSpec.describe DecisionReviews::NotificationEmailToPdfService do
  let(:user) { create(:user, :loa3, ssn: '212222112') }
  let(:submitted_appeal_uuid) { SecureRandom.uuid }
  let(:notification_id) { SecureRandom.uuid }

  let(:appeal_submission) do
    create(:appeal_submission_module,
           user_uuid: user.uuid,
           user_account: user.user_account,
           submitted_appeal_uuid:,
           type_of_appeal: 'SC')
  end

  let(:mpi_profile) do
    build(:mpi_profile,
          given_names: %w[John Michael],
          family_name: 'Doe',
          icn: user.icn)
  end

  let(:payload_hash) do
    {
      'to' => 'veteran@example.com',
      'sent_at' => '2025-11-01T10:00:00Z',
      'template_id' => '12345',
      'notification_id' => notification_id
    }
  end

  let(:audit_log) do
    OpenStruct.new(
      notification_id:,
      reference:,
      status: 'delivered',
      payload: payload_hash.to_json
    )
  end

  before do
    allow(appeal_submission).to receive(:get_mpi_profile).and_return(mpi_profile)
    allow(AppealSubmission).to receive(:find_by).with(submitted_appeal_uuid:).and_return(appeal_submission)
  end

  describe '#initialize' do
    context 'with valid audit_log for SC form failure' do
      let(:reference) { "SC-form-#{submitted_appeal_uuid}" }

      it 'initializes successfully' do
        service = described_class.new(audit_log)
        expect(service).to be_instance_of(described_class)
      end

      it 'extracts template_type correctly' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@template_type)).to eq('sc_form_failure')
      end

      it 'extracts email_address correctly' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@email_address)).to eq('veteran@example.com')
      end

      it 'extracts sent_date correctly' do
        service = described_class.new(audit_log)
        sent_date = service.instance_variable_get(:@sent_date)
        expect(sent_date).to be_a(Time)
        expect(sent_date.strftime('%Y-%m-%d')).to eq('2025-11-01')
      end

      it 'extracts first_name from MPI profile' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@first_name)).to eq('John')
      end

      it 'sets evidence_filename to nil for form failures' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@evidence_filename)).to be_nil
      end
    end

    context 'with valid audit_log for HLR form failure' do
      let(:reference) { "HLR-form-#{submitted_appeal_uuid}" }

      it 'extracts template_type correctly' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@template_type)).to eq('hlr_form_failure')
      end
    end

    context 'with valid audit_log for NOD form failure' do
      let(:reference) { "NOD-form-#{submitted_appeal_uuid}" }

      it 'extracts template_type correctly' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@template_type)).to eq('nod_form_failure')
      end
    end

    context 'with valid audit_log for SC secondary_form (4142) failure' do
      let(:reference) { "SC-secondary_form-#{submitted_appeal_uuid}" }

      it 'extracts template_type correctly' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@template_type)).to eq('sc_4142_failure')
      end
    end

    context 'with valid audit_log for SC evidence failure' do
      let(:reference) { "SC-evidence-#{submitted_appeal_uuid}" }
      let(:evidence_attachment_guid) { SecureRandom.uuid }
      let(:file_data) do
        { 'filename' => 'veteran_medical_evidence_document.pdf' }.to_json
      end

      let(:decision_review_evidence_attachment) do
        double('DecisionReviewEvidenceAttachment',
               guid: evidence_attachment_guid,
               file_data:)
      end

      let(:appeal_submission_upload) do
        double('AppealSubmissionUpload',
               decision_review_evidence_attachment_guid: evidence_attachment_guid,
               decision_review_evidence_attachment:,
               masked_attachment_filename: 'vetXXXXXXXXXXXXXXXXXXXXXXXXXent.pdf')
      end

      before do
        allow(appeal_submission).to receive(:appeal_submission_uploads)
          .and_return(double(order: double(first: appeal_submission_upload)))
      end

      it 'extracts template_type correctly' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@template_type)).to eq('sc_evidence_failure')
      end

      it 'extracts evidence_filename for evidence failures' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@evidence_filename)).to eq('vetXXXXXXXXXXXXXXXXXXXXXXXXXent.pdf')
      end
    end

    context 'with valid audit_log for NOD evidence failure' do
      let(:reference) { "NOD-evidence-#{submitted_appeal_uuid}" }
      let(:evidence_attachment_guid) { SecureRandom.uuid }
      let(:file_data) do
        { 'filename' => 'board_appeal_supporting_document.pdf' }.to_json
      end

      let(:decision_review_evidence_attachment) do
        double('DecisionReviewEvidenceAttachment',
               guid: evidence_attachment_guid,
               file_data:)
      end

      let(:appeal_submission_upload) do
        double('AppealSubmissionUpload',
               decision_review_evidence_attachment_guid: evidence_attachment_guid,
               decision_review_evidence_attachment:,
               masked_attachment_filename: 'boaXXXXXXXXXXXXXXXXXXXXXXXXXent.pdf')
      end

      before do
        allow(appeal_submission).to receive(:appeal_submission_uploads)
          .and_return(double(order: double(first: appeal_submission_upload)))
      end

      it 'extracts template_type correctly' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@template_type)).to eq('nod_evidence_failure')
      end

      it 'extracts evidence_filename for evidence failures' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@evidence_filename)).to eq('boaXXXXXXXXXXXXXXXXXXXXXXXXXent.pdf')
      end
    end

    context 'with payload as hash instead of JSON string' do
      let(:reference) { "SC-form-#{submitted_appeal_uuid}" }
      let(:audit_log_with_hash_payload) do
        OpenStruct.new(
          notification_id:,
          reference:,
          status: 'delivered',
          payload: payload_hash # Hash instead of JSON string
        )
      end

      it 'parses hash payload correctly' do
        service = described_class.new(audit_log_with_hash_payload)
        expect(service.instance_variable_get(:@email_address)).to eq('veteran@example.com')
      end
    end

    context 'with payload using symbol keys' do
      let(:reference) { "SC-form-#{submitted_appeal_uuid}" }
      let(:symbol_payload) do
        {
          to: 'veteran@example.com',
          sent_at: '2025-11-01T10:00:00Z'
        }
      end
      let(:audit_log_with_symbols) do
        OpenStruct.new(
          notification_id:,
          reference:,
          status: 'delivered',
          payload: symbol_payload
        )
      end

      it 'handles symbol keys in payload' do
        service = described_class.new(audit_log_with_symbols)
        expect(service.instance_variable_get(:@email_address)).to eq('veteran@example.com')
      end
    end

    context 'when MPI profile has no given_names' do
      let(:reference) { "SC-form-#{submitted_appeal_uuid}" }
      let(:mpi_profile_no_names) do
        build(:mpi_profile,
              given_names: nil,
              family_name: 'Doe',
              icn: user.icn)
      end

      before do
        allow(appeal_submission).to receive(:get_mpi_profile).and_return(mpi_profile_no_names)
      end

      it 'defaults first_name to "Veteran"' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@first_name)).to eq('Veteran')
      end
    end

    context 'when MPI profile is nil' do
      let(:reference) { "SC-form-#{submitted_appeal_uuid}" }

      before do
        allow(appeal_submission).to receive(:get_mpi_profile).and_return(nil)
      end

      it 'defaults first_name to "Veteran"' do
        service = described_class.new(audit_log)
        expect(service.instance_variable_get(:@first_name)).to eq('Veteran')
      end
    end

    context 'with nil audit_log' do
      it 'raises ArgumentError' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError, 'audit_log is required')
      end
    end

    context 'with unknown template type in reference' do
      let(:reference) { "SC-unknown_type-#{submitted_appeal_uuid}" }

      it 'raises ArgumentError' do
        expect do
          described_class.new(audit_log)
        end.to raise_error(ArgumentError, /Unable to determine template type from reference/)
      end
    end

    context 'when AppealSubmission not found' do
      let(:reference) { "SC-form-#{submitted_appeal_uuid}" }

      before do
        allow(AppealSubmission).to receive(:find_by).with(submitted_appeal_uuid:).and_return(nil)
      end

      it 'raises ArgumentError' do
        expect do
          described_class.new(audit_log)
        end.to raise_error(ArgumentError, /AppealSubmission not found for UUID/)
      end
    end

    context 'when evidence filename not found for evidence failure' do
      let(:reference) { "SC-evidence-#{submitted_appeal_uuid}" }

      before do
        allow(appeal_submission).to receive(:appeal_submission_uploads)
          .and_return(double(order: double(first: nil)))
      end

      it 'raises ArgumentError' do
        expect do
          described_class.new(audit_log)
        end.to raise_error(ArgumentError, /Evidence filename not found for submission UUID/)
      end
    end
  end

  describe '#generate_pdf' do
    let(:reference) { "SC-form-#{submitted_appeal_uuid}" }
    let(:stamper) { instance_double(DecisionReviews::PdfTemplateStamper) }
    let(:pdf_binary) { '%PDF-1.4 fake pdf content' }

    before do
      allow(DecisionReviews::PdfTemplateStamper).to receive(:new).and_return(stamper)
      allow(stamper).to receive(:stamp_personalized_data).and_return(pdf_binary)
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:binwrite)
      allow(SecureRandom).to receive(:hex).and_return('abc123')
    end

    it 'creates a PdfTemplateStamper with correct template_type' do
      service = described_class.new(audit_log)
      service.generate_pdf

      expect(DecisionReviews::PdfTemplateStamper).to have_received(:new).with(template_type: 'sc_form_failure')
    end

    it 'calls stamp_personalized_data with correct parameters' do
      service = described_class.new(audit_log)
      service.generate_pdf

      expect(stamper).to have_received(:stamp_personalized_data).with(
        first_name: 'John',
        submission_date: appeal_submission.created_at,
        email_address: 'veteran@example.com',
        sent_date: kind_of(Time),
        evidence_filename: nil
      )
    end

    it 'creates the tmp/pdfs directory' do
      service = described_class.new(audit_log)
      service.generate_pdf

      expect(FileUtils).to have_received(:mkdir_p).with('tmp/pdfs')
    end

    it 'saves the PDF to a file' do
      service = described_class.new(audit_log)
      service.generate_pdf

      expect(File).to have_received(:binwrite).with('tmp/pdfs/dr_email_ABC123.pdf', pdf_binary)
    end

    it 'returns the file path' do
      service = described_class.new(audit_log)
      file_path = service.generate_pdf

      expect(file_path).to eq('tmp/pdfs/dr_email_ABC123.pdf')
    end

    context 'with evidence failure' do
      let(:reference) { "SC-evidence-#{submitted_appeal_uuid}" }
      let(:evidence_attachment_guid) { SecureRandom.uuid }
      let(:file_data) do
        { 'filename' => 'veteran_medical_evidence_document.pdf' }.to_json
      end

      let(:decision_review_evidence_attachment) do
        double('DecisionReviewEvidenceAttachment',
               guid: evidence_attachment_guid,
               file_data:)
      end

      let(:appeal_submission_upload) do
        double('AppealSubmissionUpload',
               decision_review_evidence_attachment_guid: evidence_attachment_guid,
               decision_review_evidence_attachment:,
               masked_attachment_filename: 'vetXXXXXXXXXXXXXXXXXXXXXXXXXent.pdf')
      end

      before do
        allow(appeal_submission).to receive(:appeal_submission_uploads)
          .and_return(double(order: double(first: appeal_submission_upload)))
      end

      it 'passes evidence_filename to stamper' do
        service = described_class.new(audit_log)
        service.generate_pdf

        expect(stamper).to have_received(:stamp_personalized_data).with(
          first_name: 'John',
          submission_date: appeal_submission.created_at,
          email_address: 'veteran@example.com',
          sent_date: kind_of(Time),
          evidence_filename: 'vetXXXXXXXXXXXXXXXXXXXXXXXXXent.pdf'
        )
      end
    end
  end

  xdescribe 'integration test - generate actual PDF for inspection' do # rubocop:disable RSpec/PendingWithoutReason
    # Disabled by default - only enable locally for manual PDF inspection
    # Output saved to: tmp/pdfs/dr_email_*.pdf
    # Open the file to verify personalized data is correctly stamped
    let(:reference) { "SC-form-#{submitted_appeal_uuid}" }

    before do
      # Ensure tmp/pdfs directory exists
      FileUtils.mkdir_p('tmp/pdfs')

      # Skip test if template doesn't exist
      template_path = Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews',
                                      'email_templates', 'sc_form_failure.pdf')
      skip "Template not found: #{template_path}" unless File.exist?(template_path)
    end

    it 'generates a real PDF file that can be inspected' do
      service = described_class.new(audit_log)
      file_path = service.generate_pdf

      expect(File.exist?(file_path)).to be true

      # Verify it's a valid PDF
      pdf_content = File.read(file_path)
      expect(pdf_content).to start_with('%PDF-')
    end
  end

  xdescribe 'integration test - generate evidence failure PDF for inspection' do # rubocop:disable RSpec/PendingWithoutReason
    # Disabled by default - only enable locally for manual PDF inspection
    # Output saved to: tmp/pdfs/dr_email_*.pdf
    # Open the file to verify personalized data is correctly stamped including evidence filename
    let(:reference) { "SC-evidence-#{submitted_appeal_uuid}" }
    let(:evidence_attachment_guid) { SecureRandom.uuid }
    let(:file_data) do
      { 'filename' => 'veteran_medical_evidence_document.pdf' }.to_json
    end

    let(:decision_review_evidence_attachment) do
      double('DecisionReviewEvidenceAttachment',
             guid: evidence_attachment_guid,
             file_data:)
    end

    let(:appeal_submission_upload) do
      double('AppealSubmissionUpload',
             decision_review_evidence_attachment_guid: evidence_attachment_guid,
             decision_review_evidence_attachment:,
             masked_attachment_filename: 'vetXXXXXXXXXXXXXXXXXXXXXXXXXent.pdf')
    end

    before do
      # Ensure tmp/pdfs directory exists
      FileUtils.mkdir_p('tmp/pdfs')

      allow(appeal_submission).to receive(:appeal_submission_uploads)
        .and_return(double(order: double(first: appeal_submission_upload)))

      # Skip test if template doesn't exist
      template_path = Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews',
                                      'email_templates', 'sc_evidence_failure.pdf')
      skip "Template not found: #{template_path}" unless File.exist?(template_path)
    end

    it 'generates a real PDF file with evidence filename that can be inspected' do
      service = described_class.new(audit_log)
      file_path = service.generate_pdf

      expect(File.exist?(file_path)).to be true

      # Verify it's a valid PDF
      pdf_content = File.read(file_path)
      expect(pdf_content).to start_with('%PDF-')
    end
  end
end
