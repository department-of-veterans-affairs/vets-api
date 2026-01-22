# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/pdf_fill/filler'
require_relative 'fill_form_examples'

describe DependentsBenefits::PdfFill::Filler, type: :model do
  include SchemaMatchers

  # see `fill_form_examples.rb` for documentation about options
  describe '#fill_form' do
    [
      {
        form_id: '21-686C',
        factory: :add_remove_dependents_claim
      },
      {
        form_id: '21-674',
        factory: :student_claim
      }
    ].each do |options|
      it_behaves_like 'a form filler', options
    end
  end

  describe '#fill_ancillary_form', run_at: '2017-07-25 00:00:00 -0400' do
    def overflow_file_suffix(extras_redesign, show_jumplinks)
      return '_extras.pdf' unless extras_redesign

      show_jumplinks ? '_redesign_extras_jumplinks.pdf' : '_redesign_extras.pdf'
    end

    %w[21-674].each do |form_id|
      context "form #{form_id}" do
        form_types = %w[simple kitchen_sink overflow].map { |type| [type, false, false] }
        form_types.each do |type, extras_redesign, show_jumplinks|
          context "with type=#{type} extras_redesign=#{extras_redesign} show_jumplinks=#{show_jumplinks}" do
            let(:form_data) do
              get_fixture_absolute("modules/dependents_benefits/spec/fixtures/pdf_fill/#{form_id}/#{type}")
            end

            it 'fills the form correctly' do
              if type == 'overflow'
                the_extras_generator = nil
                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id,
                                                              { extras_redesign:, show_jumplinks: })

              fixture_pdf_base = "modules/dependents_benefits/spec/fixtures/pdf_fill/#{form_id}/#{type}"

              if type == 'overflow'
                extras_path = the_extras_generator.generate
                fixture_pdf = fixture_pdf_base + overflow_file_suffix(extras_redesign, show_jumplinks)
                expect(extras_path).to match_file_exactly(fixture_pdf)

                File.delete(extras_path)
              end

              fixture_pdf = fixture_pdf_base + (extras_redesign ? '_redesign.pdf' : '.pdf')
              expect(file_path).to match_pdf_fields(fixture_pdf)

              File.delete(file_path)
            end
          end
        end
      end
    end
  end

  describe '#stamp_form' do
    subject { described_class.stamp_form(file_path, submit_date) }

    let(:file_path) { 'tmp/test.pdf' }
    let(:submit_date) { DateTime.new(2020, 12, 25, 14, 30, 0, '+0000') }
    let(:datestamp_pdf) { instance_double(PDFUtilities::DatestampPdf) }
    let(:stamped_path) { 'tmp/test_stamped.pdf' }
    let(:final_path) { 'tmp/test_final.pdf' }

    before do
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_pdf)
      allow(datestamp_pdf).to receive(:run).and_return(stamped_path, final_path)
    end

    it 'stamps the form with footer and header' do
      expected_footer = 'Signed electronically and submitted via VA.gov at 14:30 UTC 2020-12-25. ' \
                        'Signee signed with an identity-verified account.'

      expect(PDFUtilities::DatestampPdf).to receive(:new).with(file_path).ordered
      expect(datestamp_pdf).to receive(:run).with(
        text: expected_footer,
        x: 5,
        y: 5,
        text_only: true,
        size: 9
      ).ordered.and_return(stamped_path)

      expect(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path).ordered
      expect(datestamp_pdf).to receive(:run).with(
        text: 'VA.gov Submission',
        x: 510,
        y: 775,
        text_only: true,
        size: 9
      ).ordered.and_return(final_path)

      expect(File).to receive(:delete).with(stamped_path)

      expect(subject).to eq(final_path)
    end

    context 'when an error occurs' do
      before do
        allow(datestamp_pdf).to receive(:run).and_raise(StandardError, 'PDF Error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and returns the original file path' do
        expect(subject).to eq(file_path)
        expect(Rails.logger).to have_received(:error).with(
          "Error stamping form for PdfFill: #{file_path}, error: PDF Error"
        )
      end
    end
  end

  describe '#combine_extras' do
    let(:old_file_path) { 'tmp/test_old.pdf' }
    let(:extras_generator) { double('ExtrasGenerator') }
    let(:form_class) { DependentsBenefits::PdfFill::Va21686c }
    let(:extras_path) { 'tmp/test_extras.pdf' }
    let(:final_file_path) { 'tmp/test_old_final.pdf' }
    let(:pdf_post_processor) { instance_double(PdfFill::PdfPostProcessor) }

    before do
      allow(extras_generator).to receive_messages(
        text?: true,
        generate: extras_path
      )
      allow(described_class).to receive(:merge_pdfs)
      allow(File).to receive(:delete)
    end

    context 'when extras_generator has section coordinates' do
      let(:section_coordinates) { [{ page: 1, x: 100, y: 200 }] }
      let(:mock_post_processor_class) do
        Class.new do
          def initialize(old_file_path, file_path, section_coordinates, form_class)
            # Mock initialization
          end

          def process!
            # Mock processing
          end
        end
      end

      before do
        allow(extras_generator).to receive(:try).with(:section_coordinates).and_return(section_coordinates)
        allow(extras_generator).to receive(:section_coordinates).and_return(section_coordinates)
        stub_const('PdfPostProcessor', mock_post_processor_class)
        allow(PdfPostProcessor).to receive(:new).and_return(pdf_post_processor)
        allow(pdf_post_processor).to receive(:process!)
      end

      it 'creates and processes PdfPostProcessor when section coordinates exist' do
        described_class.combine_extras(old_file_path, extras_generator, form_class)

        expect(PdfPostProcessor).to have_received(:new).with(
          old_file_path,
          final_file_path,
          section_coordinates,
          form_class
        )
        expect(pdf_post_processor).to have_received(:process!)
      end
    end

    context 'when extras_generator has empty section coordinates' do
      let(:mock_post_processor_class) { Class.new }

      before do
        allow(extras_generator).to receive(:try).with(:section_coordinates).and_return([])
        allow(extras_generator).to receive(:section_coordinates).and_return([])
        stub_const('PdfPostProcessor', mock_post_processor_class)
        allow(PdfPostProcessor).to receive(:new)
      end

      it 'does not create PdfPostProcessor when section coordinates are empty' do
        described_class.combine_extras(old_file_path, extras_generator, form_class)

        expect(PdfPostProcessor).not_to have_received(:new)
      end
    end

    context 'when extras_generator does not have section_coordinates method' do
      let(:mock_post_processor_class) { Class.new }

      before do
        allow(extras_generator).to receive(:try).with(:section_coordinates).and_return(nil)
        stub_const('PdfPostProcessor', mock_post_processor_class)
        allow(PdfPostProcessor).to receive(:new)
      end

      it 'does not create PdfPostProcessor when section_coordinates method does not exist' do
        described_class.combine_extras(old_file_path, extras_generator, form_class)

        expect(PdfPostProcessor).not_to have_received(:new)
      end
    end

    context 'when extras_generator does not have text' do
      let(:mock_post_processor_class) { Class.new }

      before do
        allow(extras_generator).to receive(:text?).and_return(false)
        stub_const('PdfPostProcessor', mock_post_processor_class)
        allow(PdfPostProcessor).to receive(:new)
      end

      it 'returns original file path without processing when no text' do
        result = described_class.combine_extras(old_file_path, extras_generator, form_class)

        expect(result).to eq(old_file_path)
        expect(PdfPostProcessor).not_to have_received(:new)
        expect(described_class).not_to have_received(:merge_pdfs)
      end
    end
  end
end
