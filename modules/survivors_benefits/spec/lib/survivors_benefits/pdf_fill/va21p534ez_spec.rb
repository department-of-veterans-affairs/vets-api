# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'survivors_benefits/pdf_fill/va21p534ez'
require 'pdf_utilities/datestamp_pdf'
require 'fileutils'
require 'tmpdir'
require 'timecop'

describe SurvivorsBenefits::PdfFill::Va21p534ez do
  include SchemaMatchers

  describe '#to_pdf' do
    it 'merges the right keys' do
      Timecop.freeze(Time.zone.parse('2025-10-27')) do
        files = %w[
          empty
          section-1 section-1_2
          section-2 section-2_1 section-2_2 section-2_3 section-2_4
          section-3 section-3_1 section-3_2 section-3_3 section-3_4 section-3_5 section-3_6 section-3_7
          section-3_8 section-3_9 section-3_10
          section-4 section-4_1 section-4_2 section-4_3 section-4_4
          section-5 section-5_1 section-5_2
          section-6 section-6_1
          section-7 section-7_1 section-7_2
          section-8 section-8_1
          section-9 section-9_1 section-9_2 section-9_3 section-9_4
          section-10 section-10_1 section-10_2 section-10_3
          section-11 section-11_1 section-11_2 section-11_3
        ]
        files.map do |file|
          f1 = File.read File.join(__dir__, 'input', "21P-534EZ_#{file}.json")

          claim = SurvivorsBenefits::SavedClaim.new(form: f1)

          form_id = SurvivorsBenefits::FORM_ID
          form_class = SurvivorsBenefits::PdfFill::Va21p534ez
          fill_options = {
            created_at: '2025-10-08'
          }
          merged_form_data = form_class.new(claim.parsed_form).merge_fields(fill_options)
          submit_date = Utilities::DateParser.parse(
            fill_options[:created_at]
          )

          hash_converter = PdfFill::Filler.make_hash_converter(form_id, form_class, submit_date, fill_options)
          new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

          f2 = File.read File.join(__dir__, 'output', "21P-534EZ_#{file}.json")
          data = JSON.parse(f2)

          filtered = new_hash.slice(*(new_hash.keys & data.keys))

          expect(filtered).to eq(data)
        end
      end
    end
  end

  describe '.stamp_signature' do
    let(:pdf_path) { '/tmp/test_form.pdf' }
    let(:stamped_path) { '/tmp/test_form_stamped.pdf' }
    let(:datestamp_instance) { instance_double(PDFUtilities::DatestampPdf) }
    let(:coordinates) { { x: 123, y: 456, page_number: 7 } }

    before do
      allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path).and_return(datestamp_instance)
      allow(described_class).to receive(:signature_overlay_coordinates).and_return(coordinates)
    end

    it 'stamps the signature when present' do
      expect(datestamp_instance).to receive(:run).with(
        text: 'Jane Doe',
        x: coordinates[:x],
        y: coordinates[:y],
        page_number: coordinates[:page_number],
        size: described_class::SIGNATURE_FONT_SIZE,
        text_only: true,
        timestamp: '',
        template: pdf_path,
        multistamp: true
      ).and_return(stamped_path)

      result = described_class.stamp_signature(pdf_path, { 'claimantSignature' => 'Jane Doe' })
      expect(result).to eq(stamped_path)
    end

    it 'builds the signature from claimant name when signature is blank' do
      expect(datestamp_instance).to receive(:run).and_return(stamped_path)

      result = described_class.stamp_signature(pdf_path,
                                               { 'claimantFullName' => { 'first' => 'Jane', 'middle' => 'Q',
                                                                         'last' => 'Doe' },
                                                 'claimantSignature' => '' })
      expect(result).to eq(stamped_path)
    end

    it 'uses statement of truth signature when present' do
      expect(datestamp_instance).to receive(:run).with(
        text: 'Jane Q Doe',
        x: coordinates[:x],
        y: coordinates[:y],
        page_number: coordinates[:page_number],
        size: described_class::SIGNATURE_FONT_SIZE,
        text_only: true,
        timestamp: '',
        template: pdf_path,
        multistamp: true
      ).and_return(stamped_path)

      result = described_class.stamp_signature(pdf_path,
                                               { 'statementOfTruthSignature' => 'Jane Q Doe',
                                                 'claimantSignature' => '' })
      expect(result).to eq(stamped_path)
    end

    it 'returns the original PDF when signature is missing' do
      result = described_class.stamp_signature(pdf_path, { 'claimantSignature' => '' })
      expect(result).to eq(pdf_path)
      expect(PDFUtilities::DatestampPdf).not_to have_received(:new)
    end

    it 'returns nil when pdf_path is nil' do
      result = described_class.stamp_signature(nil, { 'claimantSignature' => 'Jane Doe' })

      expect(result).to be_nil
      expect(described_class).not_to have_received(:signature_overlay_coordinates)
      expect(PDFUtilities::DatestampPdf).not_to have_received(:new)
    end

    it 'falls back to template coordinates when filled PDF lacks widget' do
      allow(described_class).to receive(:signature_overlay_coordinates).with(pdf_path).and_return(nil)
      allow(described_class).to receive(:signature_overlay_coordinates)
        .with(described_class::TEMPLATE).and_return(coordinates)

      expect(datestamp_instance).to receive(:run).and_return(stamped_path)

      result = described_class.stamp_signature(pdf_path, { 'claimantSignature' => 'Jane Doe' })
      expect(result).to eq(stamped_path)
    end

    it 'rescues errors and returns the original PDF path' do
      allow(datestamp_instance).to receive(:run).and_raise(StandardError, 'boom')

      result = described_class.stamp_signature(pdf_path, { 'claimantSignature' => 'Jane Doe' })
      expect(result).to eq(pdf_path)
    end
  end
end
