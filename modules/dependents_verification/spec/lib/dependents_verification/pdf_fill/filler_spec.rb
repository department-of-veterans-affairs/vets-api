# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

describe PdfFill::Filler, type: :model do
  include SchemaMatchers

  describe '#fill_ancillary_form', run_at: '2025-06-25 00:00:00 UTC' do
    %w[21-0538].each do |form_id|
      context "form #{form_id}" do
        %w[simple kitchen_sink overflow].each do |type|
          context "with #{type} test data" do
            let(:form_data) do
              JSON.parse(File.read("modules/dependents_verification/spec/fixtures/pdf_fill/#{form_id}/#{type}.json"))
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

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id)

              if type == 'overflow'
                extras_path = the_extras_generator.generate
                expected_path = "modules/dependents_verification/spec/fixtures/pdf_fill/#{form_id}/overflow_extras.pdf"
                expect(
                  FileUtils.compare_file(extras_path, expected_path)
                ).to be(true)

                File.delete(extras_path)
              end

              expected_path = "modules/dependents_verification/spec/fixtures/pdf_fill/#{form_id}/#{type}.pdf"

              expect(file_path).to match_pdf_fields(expected_path)

              File.delete(file_path)
            end
          end
        end
      end
    end
  end
end
