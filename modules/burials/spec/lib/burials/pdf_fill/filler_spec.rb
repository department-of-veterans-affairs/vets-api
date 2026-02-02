# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'
require 'pdf-reader'

describe PdfFill::Filler, type: :model do
  include SchemaMatchers

  describe '#fill_ancillary_form', run_at: '2017-07-25 00:00:00 -0400' do
    %w[21P-530EZ].each do |form_id|
      context "form #{form_id}" do
        %w[simple kitchen_sink overflow].each do |type|
          context "with #{type} test data" do
            let(:form_data) do
              JSON.parse(File.read("modules/burials/spec/fixtures/pdf_fill/#{form_id}/#{type}.json"))
            end

            it 'fills the form correctly' do
              allow(Flipper).to receive(:enabled?).with(:burial_pdf_form_alignment).and_return(false)

              if type == 'overflow'
                # pdfs_fields_match? only compares based on filled fields, it doesn't read the extras page
                the_extras_generator = nil
                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              fill_options = { extras_redesign: true, omit_esign_stamp: true, use_hexapdf: true }

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id,
                                                              fill_options)

              if type == 'overflow'
                expect(the_extras_generator).not_to be_nil, 'combine_extras should have been called'
                extras_path = the_extras_generator.generate
                expected_path = "modules/burials/spec/fixtures/pdf_fill/#{form_id}/overflow_redesign_extras.pdf"

                expect(
                  FileUtils.compare_file(extras_path, expected_path)
                ).to be(true)

                File.delete(extras_path)
              end

              expected_path = "modules/burials/spec/fixtures/pdf_fill/#{form_id}/#{type}_redesign.pdf"
              expect(file_path).to match_pdf_fields(expected_path)

              File.delete(file_path)
            end

            it 'fills the form correctly with V2' do
              allow(Flipper).to receive(:enabled?).with(:burial_pdf_form_alignment).and_return(true)

              if type == 'overflow'
                # pdfs_fields_match? only compares based on filled fields, it doesn't read the extras page
                the_extras_generator = nil
                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              fill_options = { extras_redesign: true, omit_esign_stamp: true, use_hexapdf: true }

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id,
                                                              fill_options)

              if type == 'overflow'
                expect(the_extras_generator).not_to be_nil, 'combine_extras should have been called'
                extras_path = the_extras_generator.generate

                expected_path = "modules/burials/spec/fixtures/pdf_fill/#{form_id}/overflow_redesign_extras_v2.pdf"

                # This gives more detailed output on where the PDFs differ
                file_texts = [extras_path, expected_path].map do |path|
                  reader1 = PDF::Reader.new(path)
                  reader1.pages.map(&:text).join('\n').squeeze
                end
                expect(file_texts[0]).to eq(file_texts[1])

                expect(extras_path).to match_file_exactly(expected_path)

                File.delete(extras_path)
              end

              expected_path = "modules/burials/spec/fixtures/pdf_fill/#{form_id}/#{type}_redesign_v2.pdf"
              expect(file_path).to match_pdf_fields(expected_path)

              File.delete(file_path)
            end
          end
        end
      end
    end
  end
end
