# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/pdf_fill/filler'
require_relative 'fill_form_examples'

describe PdfFill::Filler, type: :model do
  include SchemaMatchers

  # see `fill_form_examples.rb` for documentation about options
  describe '#fill_form' do
    [
      {
        form_id: '686C-674-V2',
        factory: :dependency_claim_v2
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

    %w[21-674-V2].each do |form_id|
      context "form #{form_id}" do
        form_types = %w[simple kitchen_sink overflow].map { |type| [type, false, false] }
        form_types.each do |type, extras_redesign, show_jumplinks|
          context "with type=#{type} extras_redesign=#{extras_redesign} show_jumplinks=#{show_jumplinks}" do
            let(:form_data) do
              get_fixture("pdf_fill/#{form_id}/#{type}")
            end

            it 'fills the form correctly' do
              if type == 'overflow'
                the_extras_generator = nil
                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              # this is only for 21-674-V2 but it passes in the extras hash. passing nil for all other scenarios
              student = form_id == '21-674-V2' ? form_data['dependents_application']['student_information'][0] : nil

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id,
                                                              { extras_redesign:, student:, show_jumplinks: })

              fixture_pdf_base = "spec/fixtures/pdf_fill/#{form_id}/#{type}"

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
end
