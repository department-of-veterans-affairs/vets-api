# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Filler, type: :model do
  include SchemaMatchers

  describe '#combine_extras' do
    subject do
      described_class.combine_extras(old_file_path, extras_generator)
    end

    let(:extras_generator) { double }
    let(:old_file_path) { 'tmp/pdfs/file_path.pdf' }

    context 'when extras_generator doesnt have text' do
      it 'returns the old_file_path' do
        expect(extras_generator).to receive(:text?).once.and_return(false)

        expect(subject).to eq(old_file_path)
      end
    end

    context 'when extras_generator has text' do
      before do
        expect(extras_generator).to receive(:text?).once.and_return(true)
      end

      it 'generates extras and combine the files' do
        file_path = 'tmp/pdfs/file_path_final.pdf'
        expect(extras_generator).to receive(:generate).once.and_return('extras.pdf')
        expect(described_class::PDF_FORMS).to receive(:cat).once.with(
          old_file_path,
          'extras.pdf',
          file_path
        )
        expect(File).to receive(:delete).once.with('extras.pdf')
        expect(File).to receive(:delete).once.with(old_file_path)

        expect(subject).to eq(file_path)
      end
    end
  end

  # see `fill_form_examples.rb` for documentation about options
  describe '#fill_form' do
    [
      {
        form_id: '686C-674',
        factory: :dependency_claim
      },
      {
        form_id: '686C-674-V2',
        factory: :dependency_claim_v2
      }
    ].each do |options|
      it_behaves_like 'a form filler', options
    end
  end

  describe '#fill_ancillary_form', run_at: '2017-07-25 00:00:00 -0400' do
    %w[21-4142 21-0781a 21-0781 21-0781V2 21-8940 28-8832 28-1900 21-674 21-674-V2 21-0538 26-1880 5655
       22-10216 22-10215].each do |form_id|
      context "form #{form_id}" do
        form_types = %w[simple kitchen_sink overflow].product([false])
        form_types << ['overflow', true] if form_id == '21-0781V2'
        form_types.each do |type, extras_redesign|
          context "with #{type} test data with extras_redesign #{extras_redesign}" do
            let(:form_data) do
              get_fixture("pdf_fill/#{form_id}/#{type}")
            end

            it 'fills the form correctly' do
              if type == 'overflow'
                # pdfs_fields_match? only compares based on filled fields, it doesn't read the extras page
                the_extras_generator = nil
                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              # this is only for 21-674-V2 but it passes in the extras hash. passing nil for all other scenarios
              student = form_id == '21-674-V2' ? form_data['dependents_application']['student_information'][0] : nil

              expect(described_class).to receive(:stamp_form).once.and_call_original if extras_redesign

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id, { extras_redesign:, student: })

              if type == 'overflow'
                extras_path = the_extras_generator.generate
                fixture_pdf = extras_redesign ? 'overflow_redesign_extras.pdf' : 'overflow_extras.pdf'
                expect(
                  FileUtils.compare_file(extras_path, "spec/fixtures/pdf_fill/#{form_id}/#{fixture_pdf}")
                ).to be(true)

                File.delete(extras_path)
              end

              expect(
                pdfs_fields_match?(file_path, "spec/fixtures/pdf_fill/#{form_id}/#{type}.pdf")
              ).to be(true)

              File.delete(file_path)
            end
          end
        end
      end
    end
  end

  describe '#stamp_form' do
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

      result = described_class.stamp_form(file_path, submit_date)
      expect(result).to eq(final_path)
    end

    context 'when an error occurs' do
      before do
        allow(datestamp_pdf).to receive(:run).and_raise(StandardError, 'PDF Error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and returns the original file path' do
        result = described_class.stamp_form(file_path, submit_date)

        expect(Rails.logger).to have_received(:error).with(
          "Error stamping form for PdfFill: #{file_path}, error: PDF Error"
        )
        expect(result).to eq(file_path)
      end
    end
  end
end
