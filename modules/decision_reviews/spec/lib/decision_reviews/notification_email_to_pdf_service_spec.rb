# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/lib/decision_reviews/notification_email_to_pdf_service'

RSpec.describe DecisionReviews::NotificationEmailToPdfService do
  let(:email_content) { File.read(Rails.root.join('modules/decision_reviews/spec/fixtures/hlr_failure_email.txt')) }
  let(:email_subject) { 'Decision Review Form Submission Error' }
  let(:email_address) { 'veteran@example.com' }
  let(:sent_date) { Time.zone.parse('2025-10-01 10:00:00') }
  let(:submission_date) { Time.zone.parse('2025-09-30 15:30:00') }

  describe '#initialize' do
    context 'with valid form template type' do
      it 'creates service for HLR form error' do
        service = described_class.new(
          email_content: email_content,
          email_subject: email_subject,
          email_address: email_address,
          sent_date: sent_date,
          submission_date: submission_date,
          template_type: :form,
          appeal_type: 'HLR'
        )

        expect(service.template_identifier).to eq('higher_level_review_form_error')
      end

      it 'creates service for NOD form error' do
        service = described_class.new(
          email_content: email_content,
          email_subject: email_subject,
          email_address: email_address,
          sent_date: sent_date,
          submission_date: submission_date,
          template_type: :form,
          appeal_type: 'NOD'
        )

        expect(service.template_identifier).to eq('notice_of_disagreement_form_error')
      end

      it 'creates service for SC form error' do
        service = described_class.new(
          email_content: email_content,
          email_subject: email_subject,
          email_address: email_address,
          sent_date: sent_date,
          submission_date: submission_date,
          template_type: :form,
          appeal_type: 'SC'
        )

        expect(service.template_identifier).to eq('supplemental_claim_form_error')
      end
    end

    context 'with valid evidence template type' do
      it 'creates service for NOD evidence error' do
        service = described_class.new(
          email_content: email_content,
          email_subject: email_subject,
          email_address: email_address,
          sent_date: sent_date,
          submission_date: submission_date,
          template_type: :evidence,
          appeal_type: 'NOD'
        )

        expect(service.template_identifier).to eq('notice_of_disagreement_evidence_error')
      end

      it 'creates service for SC evidence error' do
        service = described_class.new(
          email_content: email_content,
          email_subject: email_subject,
          email_address: email_address,
          sent_date: sent_date,
          submission_date: submission_date,
          template_type: :evidence,
          appeal_type: 'SC'
        )

        expect(service.template_identifier).to eq('supplemental_claim_evidence_error')
      end
    end

    context 'with valid secondary form template type' do
      it 'creates service for SC secondary form error' do
        service = described_class.new(
          email_content: email_content,
          email_subject: email_subject,
          email_address: email_address,
          sent_date: sent_date,
          submission_date: submission_date,
          template_type: :secondary_form
        )

        expect(service.template_identifier).to eq('supplemental_claim_secondary_form_error')
      end
    end

    context 'with invalid template type' do
      it 'raises ArgumentError for unknown template type' do
        expect {
          described_class.new(
            email_content: email_content,
            email_subject: email_subject,
            email_address: email_address,
            sent_date: sent_date,
            submission_date: submission_date,
            template_type: :invalid_type
          )
        }.to raise_error(ArgumentError, /Invalid template_type: invalid_type/)
      end
    end

    context 'with invalid appeal type for form template' do
      it 'raises ArgumentError for unknown appeal type' do
        expect {
          described_class.new(
            email_content: email_content,
            email_subject: email_subject,
            email_address: email_address,
            sent_date: sent_date,
            submission_date: submission_date,
            template_type: :form,
            appeal_type: 'INVALID'
          )
        }.to raise_error(ArgumentError, /Invalid appeal_type for form: INVALID/)
      end

      it 'raises ArgumentError when appeal_type is missing for form template' do
        expect {
          described_class.new(
            email_content: email_content,
            email_subject: email_subject,
            email_address: email_address,
            sent_date: sent_date,
            submission_date: submission_date,
            template_type: :form,
            appeal_type: nil
          )
        }.to raise_error(ArgumentError, /Invalid appeal_type for form/)
      end
    end

    context 'with invalid appeal type for evidence template' do
      it 'raises ArgumentError for HLR evidence (not supported)' do
        expect {
          described_class.new(
            email_content: email_content,
            email_subject: email_subject,
            email_address: email_address,
            sent_date: sent_date,
            submission_date: submission_date,
            template_type: :evidence,
            appeal_type: 'HLR'
          )
        }.to raise_error(ArgumentError, /Invalid appeal_type for evidence: HLR/)
      end
    end
  end

  describe '#generate_pdf' do
    let(:service) do
      described_class.new(
        email_content: email_content,
        email_subject: email_subject,
        email_address: email_address,
        sent_date: sent_date,
        submission_date: submission_date,
        template_type: :form,
        appeal_type: 'SC'
      )
    end

    it 'generates a PDF file and returns the file path' do
      pdf_path = service.generate_pdf

      expect(pdf_path).to be_a(String)
      expect(pdf_path).to match(%r{tmp/pdfs/dr_email_.*\.pdf})
      expect(File.exist?(pdf_path)).to be true

      # Verify it's a valid PDF file
      pdf_content = File.read(pdf_path)
      expect(pdf_content).to start_with('%PDF-')
      expect(pdf_content).to end_with("%%EOF\n")
    end

    it 'creates a PDF file with proper content structure' do
      pdf_path = service.generate_pdf

      # Verify the PDF file exists and has proper structure
      expect(File.exist?(pdf_path)).to be true
      pdf_content = File.read(pdf_path)
      expect(pdf_content.length).to be > 1000 # Should be a substantial PDF
      expect(pdf_content).to include('obj') # PDF object markers
      expect(pdf_content).to include('endobj')
    end

    it 'generates unique file paths for each generation' do
      pdf_path1 = service.generate_pdf
      pdf_path2 = service.generate_pdf
      
      # Verify that each generation creates a different file
      expect(pdf_path1).not_to eq(pdf_path2)
      expect(File.exist?(pdf_path1)).to be true
      expect(File.exist?(pdf_path2)).to be true
      
      # Verify files have different content (due to different generation timestamps)
      content1 = File.read(pdf_path1)
      content2 = File.read(pdf_path2)
      expect(content1).not_to eq(content2)
    end

    it 'handles long email content gracefully' do
      long_content = 'This is a very long email content. ' * 100
      long_service = described_class.new(
        email_content: long_content,
        email_subject: email_subject,
        email_address: email_address,
        sent_date: sent_date,
        submission_date: submission_date,
        template_type: :form,
        appeal_type: 'SC'
      )

      pdf_path = long_service.generate_pdf
      
      expect(File.exist?(pdf_path)).to be true
      pdf_content = File.read(pdf_path)
      expect(pdf_content.length).to be > 2000 # Should be larger due to long content
    end
  end

  describe '#template_identifier' do
    context 'for all supported template combinations' do
      let(:test_cases) do
        [
          { template_type: :form, appeal_type: 'HLR', expected: 'higher_level_review_form_error' },
          { template_type: :form, appeal_type: 'NOD', expected: 'notice_of_disagreement_form_error' },
          { template_type: :form, appeal_type: 'SC', expected: 'supplemental_claim_form_error' },
          { template_type: :evidence, appeal_type: 'NOD', expected: 'notice_of_disagreement_evidence_error' },
          { template_type: :evidence, appeal_type: 'SC', expected: 'supplemental_claim_evidence_error' },
          { template_type: :secondary_form, appeal_type: nil, expected: 'supplemental_claim_secondary_form_error' }
        ]
      end

      it 'returns correct identifiers for all combinations' do
        test_cases.each do |test_case|
          service_params = {
            email_content: email_content,
            email_subject: email_subject,
            email_address: email_address,
            sent_date: sent_date,
            submission_date: submission_date,
            template_type: test_case[:template_type]
          }
          service_params[:appeal_type] = test_case[:appeal_type] if test_case[:appeal_type]

          service = described_class.new(**service_params)
          expect(service.template_identifier).to eq(test_case[:expected])
        end
      end
    end
  end
end
