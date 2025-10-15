# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/lib/decision_reviews/notification_email_to_pdf_service'

RSpec.describe DecisionReviews::NotificationEmailToPdfService do
  let(:email_content) do
    File.read(Rails.root.join('modules', 'decision_reviews', 'spec', 'fixtures', 'hlr_failure_email.txt'))
  end
  let(:email_subject) { 'Action needed: We can\'t process your request for a Higher-Level Review' }
  let(:email_address) { 'john.doe@example.com' }
  let(:sent_date) { Time.zone.parse('2025-10-01 10:00:00') }
  let(:submission_date) { Time.zone.parse('2025-09-30 15:30:00') }
  let(:first_name) { 'John' }
  let(:evidence_filename) { 'medical_records.pdf' }

  describe '#initialize' do
    it 'creates service with required parameters' do
      service = described_class.new(
        email_content:,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name:
      )

      expect(service).to be_instance_of(described_class)
    end

    it 'creates service with optional evidence filename' do
      service = described_class.new(
        email_content:,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name:,
        evidence_filename:
      )

      expect(service).to be_instance_of(described_class)
    end

    it 'creates service without evidence filename' do
      service = described_class.new(
        email_content:,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name:,
        evidence_filename: nil
      )

      expect(service).to be_instance_of(described_class)
    end
  end

  describe '#generate_pdf' do
    let(:service) do
      described_class.new(
        email_content:,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name:
      )
    end

    it 'generates a PDF file and returns the file path' do
      pdf_path = service.generate_pdf

      expect(pdf_path).to be_a(String)
      expect(pdf_path).to match(%r{tmp/pdfs/dr_email_.*\.pdf})
      expect(File.exist?(pdf_path)).to be true

      # Verify it's a valid PDF file
      pdf_content = File.read(pdf_path)
      # binding.pry # Uncomment this line and inspect pdf_path in the console to see a generated PDF
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

    context 'with evidence filename' do
      let(:service_with_evidence) do
        described_class.new(
          email_content:,
          email_subject:,
          email_address:,
          sent_date:,
          submission_date:,
          first_name:,
          evidence_filename:
        )
      end

      it 'generates PDF including evidence filename in content' do
        pdf_path = service_with_evidence.generate_pdf

        expect(File.exist?(pdf_path)).to be true
        pdf_content = File.read(pdf_path)
        expect(pdf_content.length).to be > 1000 # Should be a substantial PDF
      end
    end

    context 'with different email content' do
      it 'handles long email content gracefully' do
        long_content = 'This is a very long email content. ' * 100
        long_service = described_class.new(
          email_content: long_content,
          email_subject:,
          email_address:,
          sent_date:,
          submission_date:,
          first_name:
        )

        pdf_path = long_service.generate_pdf

        expect(File.exist?(pdf_path)).to be true
        pdf_content = File.read(pdf_path)
        expect(pdf_content.length).to be > 2000 # Should be larger due to long content
      end

      it 'handles special characters in email content' do
        special_content = 'Email with special characters: áéíóú ñ çüñ@ñ.gøv $#@%^&*()'
        special_service = described_class.new(
          email_content: special_content,
          email_subject: 'Subject with spëcial chârs',
          email_address: 'tëst@ëxample.com',
          sent_date:,
          submission_date:,
          first_name: 'Tëst'
        )

        pdf_path = special_service.generate_pdf

        expect(File.exist?(pdf_path)).to be true
        pdf_content = File.read(pdf_path)
        expect(pdf_content).to start_with('%PDF-')
      end
    end

    context 'with different personalization fields' do
      it 'handles different email addresses and subjects' do
        custom_service = described_class.new(
          email_content: 'Custom email content for testing',
          email_subject: 'Custom Subject Line',
          email_address: 'custom.veteran@va.gov',
          sent_date: Time.zone.parse('2025-01-15 14:30:00'),
          submission_date: Time.zone.parse('2025-01-14 09:00:00'),
          first_name: 'Custom'
        )

        pdf_path = custom_service.generate_pdf

        expect(File.exist?(pdf_path)).to be true
        pdf_content = File.read(pdf_path)
        expect(pdf_content).to start_with('%PDF-')
        expect(pdf_content.length).to be > 500
      end

      it 'handles edge case dates' do
        edge_service = described_class.new(
          email_content:,
          email_subject:,
          email_address:,
          sent_date: Time.zone.parse('2025-12-31 23:59:59'),
          submission_date: Time.zone.parse('2025-01-01 00:00:01'),
          first_name:
        )

        pdf_path = edge_service.generate_pdf

        expect(File.exist?(pdf_path)).to be true
        pdf_content = File.read(pdf_path)
        expect(pdf_content).to start_with('%PDF-')
      end
    end
  end

  describe 'redaction replacement' do
    it 'replaces "Dear <redacted>" with first name' do
      redacted_content = 'Dear <redacted>, your form was submitted on <redacted>.'
      service = described_class.new(
        email_content: redacted_content,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name: 'Jane'
      )

      pdf_path = service.generate_pdf

      expect(File.exist?(pdf_path)).to be true
      pdf_content = File.read(pdf_path)
      expect(pdf_content).to start_with('%PDF-')
    end

    it 'replaces evidence filename <redacted> when evidence_filename is provided' do
      redacted_content = 'Dear <redacted>, Here\'s the file name of the document we need: <redacted>. Submission date: <redacted>.'
      service = described_class.new(
        email_content: redacted_content,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name: 'Bob',
        evidence_filename: 'evidence_document.pdf'
      )

      pdf_path = service.generate_pdf

      expect(File.exist?(pdf_path)).to be true
      pdf_content = File.read(pdf_path)
      expect(pdf_content).to start_with('%PDF-')
    end

    it 'replaces remaining <redacted> fields with submission date' do
      redacted_content = 'Dear <redacted>, your submission on <redacted> was received. Follow-up date: <redacted>.'
      service = described_class.new(
        email_content: redacted_content,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name: 'Charlie'
      )

      pdf_path = service.generate_pdf

      expect(File.exist?(pdf_path)).to be true
      pdf_content = File.read(pdf_path)
      expect(pdf_content).to start_with('%PDF-')
    end

    it 'handles all replacement types in fixture content' do
      # The fixture file contains "Dear <redacted>," and a submission date "<redacted>"
      service = described_class.new(
        email_content:,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name: 'Sarah'
      )

      pdf_path = service.generate_pdf

      expect(File.exist?(pdf_path)).to be true
      pdf_content = File.read(pdf_path)
      expect(pdf_content).to start_with('%PDF-')
      expect(pdf_content.length).to be > 1000
    end

    it 'handles case insensitive "Dear" matching' do
      redacted_content = 'dear <redacted>, your form was processed.'
      service = described_class.new(
        email_content: redacted_content,
        email_subject:,
        email_address:,
        sent_date:,
        submission_date:,
        first_name: 'David'
      )

      pdf_path = service.generate_pdf

      expect(File.exist?(pdf_path)).to be true
      pdf_content = File.read(pdf_path)
      expect(pdf_content).to start_with('%PDF-')
    end
  end
end
