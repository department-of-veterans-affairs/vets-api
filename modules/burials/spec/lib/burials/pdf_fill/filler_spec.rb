# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

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

                expect(
                  FileUtils.compare_file(extras_path,
                                         "modules/burials/spec/fixtures/pdf_fill/#{form_id}/overflow_extras.pdf")
                ).to be(true)

                File.delete(extras_path)
              end

              expect(file_path).to match_pdf_fields("modules/burials/spec/fixtures/pdf_fill/#{form_id}/#{type}.pdf")

              File.delete(file_path)
            end
          end
        end
      end
    end
  end
end
