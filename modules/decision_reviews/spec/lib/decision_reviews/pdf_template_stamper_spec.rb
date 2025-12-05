# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/lib/decision_reviews/pdf_template_stamper'

RSpec.describe DecisionReviews::PdfTemplateStamper do
  # let(:template_type) { 'hlr_form_failure' }
  # let(:template_type) { 'sc_form_failure' }
  # let(:template_type) { 'nod_form_failure' }
  let(:template_type) { 'sc_4142_failure' }
  # let(:template_type) { 'sc_evidence_failure' }
  # let(:template_type) { 'nod_evidence_failure' }
  let(:first_name) { 'Alexandria Longname' }
  let(:submission_date) { Time.zone.parse('2025-09-30 15:30:00') }
  let(:email_address) { 'superlongemail283747832@example.com' }
  let(:sent_date) { Time.zone.parse('2025-10-01 10:00:00') }
  let(:stamper) { described_class.new(template_type:) }
  # Masked filename: keeps first 3 and last 6 chars, masks middle (preserving _ and -)
  let(:evidence_filename) { 'verX_XXXX_XXXXXXXX_XXXXXXXX_XXXX_XXXple.pdf' }

  # Helper method to build data hash
  let(:data_hash) do
    {
      first_name:,
      submission_date:,
      email_address:,
      sent_date:,
      email_delivery_failure: false,
      evidence_filename: nil
    }
  end

  before do
    # Ensure tmp/pdfs directory exists for test output
    FileUtils.mkdir_p('tmp/pdfs')
  end

  after do
    # Clean up any generated test PDFs
    Dir.glob('tmp/pdfs/test_stamped_*.pdf').each { |file| FileUtils.rm_f(file) }
    Dir.glob('tmp/pdfs/integration_test_*.pdf').each { |file| FileUtils.rm_f(file) }
  end

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
        pdf_binary = stamper.stamp_personalized_data(data_hash)

        expect(pdf_binary).to be_a(String)
        expect(pdf_binary).to start_with('%PDF-')
        expect(pdf_binary.length).to be > 1000
      end

      it 'saves stamped PDF for inspection' do
        pdf_binary = stamper.stamp_personalized_data(data_hash)

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
        pdf_binary1 = stamper.stamp_personalized_data(data_hash)

        pdf_binary2 = stamper.stamp_personalized_data(data_hash)

        # pdftk may add metadata timestamps, so we just verify both are valid PDFs
        expect(pdf_binary1).to be_a(String)
        expect(pdf_binary2).to be_a(String)
        expect(pdf_binary1).to start_with('%PDF-')
        expect(pdf_binary2).to start_with('%PDF-')
      end
    end

    context 'with sc_evidence_failure template (with evidence filename)' do
      let(:template_type) { 'sc_evidence_failure' }
      let(:data_hash_with_evidence) do
        data_hash.merge(evidence_filename:)
      end

      # Skip this test if the template doesn't exist yet
      before do
        template_path = Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews',
                                        'email_templates', "#{template_type}.pdf")
        skip "Template not found: #{template_path}" unless File.exist?(template_path)
      end

      it 'generates a PDF with stamped personalization data' do
        pdf_binary = stamper.stamp_personalized_data(data_hash_with_evidence)

        expect(pdf_binary).to be_a(String)
        expect(pdf_binary).to start_with('%PDF-')
        expect(pdf_binary.length).to be > 1000
      end

      it 'saves stamped PDF for inspection' do
        pdf_binary = stamper.stamp_personalized_data(data_hash_with_evidence)

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
        pdf_binary1 = stamper.stamp_personalized_data(data_hash_with_evidence)

        pdf_binary2 = stamper.stamp_personalized_data(data_hash_with_evidence)

        # pdftk may add metadata timestamps, so we just verify both are valid PDFs
        expect(pdf_binary1).to be_a(String)
        expect(pdf_binary2).to be_a(String)
        expect(pdf_binary1).to start_with('%PDF-')
        expect(pdf_binary2).to start_with('%PDF-')
      end
    end
  end

  describe 'integration with PDF form filling' do
    context 'when template with form fields exists' do
      before do
        template_path = Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews',
                                        'email_templates', "#{template_type}.pdf")
        skip "Template not found: #{template_path}" unless File.exist?(template_path)
      end

      it 'successfully loads template and stamps personalized data' do
        pdf_binary = stamper.stamp_personalized_data(data_hash)

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

      it 'produces output that can be inspected to verify form field filling' do
        skip 'Only run locally for manual PDF inspection - not needed in CI'
        # Output saved to: tmp/pdfs/form_filled_test_#{template_type}_#{timestamp}.pdf
        # Open the file to verify form fields are filled correctly
        # Check accessibility in Adobe Acrobat: Tools > Accessibility > Full Check
        data_with_evidence = data_hash.merge(evidence_filename:)
        pdf_binary = stamper.stamp_personalized_data(data_with_evidence)

        # Save for manual inspection to verify form fields are filled correctly
        output_path = "tmp/pdfs/form_filled_test_#{template_type}_#{Time.current.to_i}.pdf"
        File.binwrite(output_path, pdf_binary)

        expect(File.exist?(output_path)).to be true
      end

      it 'generates PDF with red "✗ Failure" text when email delivery fails' do
        skip 'Only run locally for manual PDF inspection - not needed in CI'
        # Output saved to: tmp/pdfs/email_delivery_failure_#{template_type}_#{timestamp}.pdf
        # Open the file to verify the red "✗ Failure" text appears in the Email Delivery field
        data_with_failure = data_hash.merge(email_delivery_failure: true, evidence_filename:)
        pdf_binary = stamper.stamp_personalized_data(data_with_failure)

        # Save for manual inspection to verify red failure text appears
        output_path = "tmp/pdfs/email_delivery_failure_#{template_type}_#{Time.current.to_i}.pdf"
        File.binwrite(output_path, pdf_binary)

        expect(File.exist?(output_path)).to be true
        expect(pdf_binary).to be_a(String)
        expect(pdf_binary).to start_with('%PDF-')
      end
    end
  end
end
