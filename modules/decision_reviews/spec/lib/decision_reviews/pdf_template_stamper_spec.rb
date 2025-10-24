# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/lib/decision_reviews/pdf_template_stamper'

RSpec.describe DecisionReviews::PdfTemplateStamper do
  # HLR
  # let(:template_type) { 'hlr_form_failure' }
  # let(:template_type) { 'sc_form_failure' }
  # let(:template_type) { 'nod_form_failure' }
  # let(:template_type) { 'sc_4142_failure' }
  let(:template_type) { 'sc_evidence_failure' }
  # let(:template_type) { 'nod_evidence_failure' }
  let(:first_name) { 'Alexandria Longname' }
  let(:submission_date) { Time.zone.parse('2025-09-30 15:30:00') }
  let(:email_address) { 'superlongemail283747832@example.com' }
  let(:sent_date) { Time.zone.parse('2025-10-01 10:00:00') }
  let(:stamper) { described_class.new(template_type:) }
  let(:evidence_filename) { 'very_long_evidence_document_name_example.pdf' }

  describe '#initialize' do
    it 'creates a stamper instance with template type' do
      expect(stamper).to be_instance_of(described_class)
    end

    it 'sets the template path correctly' do
      expected_path = Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews',
                                      'email_templates', "#{template_type}.pdf")
      expect(stamper.instance_variable_get(:@template_path)).to eq(expected_path)
    end
  end

  describe '#stamp_personalized_data' do
    context 'with hlr_form_failure template (no evidence filename)' do
      # Skip this test if the template doesn't exist yet
      before do
        template_path = Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews',
                                        'email_templates', "#{template_type}.pdf")
        skip "Template not found: #{template_path}" unless File.exist?(template_path)
      end

      it 'generates a PDF with stamped personalization data' do
        pdf_binary = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:
        )

        expect(pdf_binary).to be_a(String)
        expect(pdf_binary).to start_with('%PDF-')
        expect(pdf_binary.length).to be > 1000
      end

      it 'saves stamped PDF for inspection' do
        pdf_binary = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:
        )

        # Save to temp file for inspection
        temp_path = "tmp/pdfs/test_stamped_#{SecureRandom.hex(4)}.pdf"
        File.binwrite(temp_path, pdf_binary)

        expect(File.exist?(temp_path)).to be true
        pdf_content = File.read(temp_path)

        # Verify it's a valid PDF
        expect(pdf_content).to start_with('%PDF-')
        expect(pdf_content).to end_with("%%EOF\n")

        # Clean up
        FileUtils.rm_f(temp_path)
      end

      it 'creates consistent output for same inputs' do
        pdf_binary1 = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:
        )

        pdf_binary2 = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:
        )

        # Should be identical since no timestamps are added
        expect(pdf_binary1).to eq(pdf_binary2)
      end
    end

    context 'with sc_evidence_failure template (with evidence filename)' do
      # Skip this test if the template doesn't exist yet
      before do
        template_path = Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews',
                                        'email_templates', "#{template_type}.pdf")
        skip "Template not found: #{template_path}" unless File.exist?(template_path)
      end

      it 'generates a PDF with stamped personalization data' do
        pdf_binary = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:,
          evidence_filename:
        )

        expect(pdf_binary).to be_a(String)
        expect(pdf_binary).to start_with('%PDF-')
        expect(pdf_binary.length).to be > 1000
      end

      it 'saves stamped PDF for inspection' do
        pdf_binary = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:,
          evidence_filename:
        )

        # Save to temp file for inspection
        temp_path = "tmp/pdfs/test_stamped_#{SecureRandom.hex(4)}.pdf"
        File.binwrite(temp_path, pdf_binary)

        expect(File.exist?(temp_path)).to be true
        pdf_content = File.read(temp_path)

        # Verify it's a valid PDF
        expect(pdf_content).to start_with('%PDF-')
        expect(pdf_content).to end_with("%%EOF\n")

        # Clean up
        FileUtils.rm_f(temp_path)
      end

      it 'creates consistent output for same inputs' do
        pdf_binary1 = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:,
          evidence_filename:
        )

        pdf_binary2 = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:,
          evidence_filename:
        )

        # Should be identical since no timestamps are added
        expect(pdf_binary1).to eq(pdf_binary2)
      end
    end
  end

  describe 'integration with Prawn template feature' do
    context 'when template exists' do
      before do
        template_path = Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews',
                                        'email_templates', "#{template_type}.pdf")
        skip "Template not found: #{template_path}" unless File.exist?(template_path)
      end

      it 'successfully loads template and stamps personalized data' do
        pdf_binary = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:
        )

        # Save and verify the PDF structure
        temp_path = "tmp/pdfs/integration_test_#{SecureRandom.hex(4)}.pdf"
        File.binwrite(temp_path, pdf_binary)

        # Verify it's a valid PDF
        pdf_content = File.read(temp_path)
        expect(pdf_content).to start_with('%PDF-')
        expect(pdf_content).to end_with("%%EOF\n")

        # Clean up
        FileUtils.rm_f(temp_path)
      end

      it 'produces output that can be inspected for coordinate calibration' do
        pdf_binary = stamper.stamp_personalized_data(
          first_name:,
          submission_date:,
          email_address:,
          sent_date:,
          evidence_filename:
        )

        # Save for manual inspection to calibrate coordinates
        output_path = "tmp/pdfs/calibration_test_#{template_type}_#{Time.current.to_i}.pdf"
        File.binwrite(output_path, pdf_binary)

        puts "\n📄 Calibration PDF saved to: #{output_path}"
        puts '   Open this file to verify coordinate placement and adjust FIELD_COORDINATES if needed'

        expect(File.exist?(output_path)).to be true
      end
    end
  end
end
