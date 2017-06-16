require 'spec_helper'
# frozen_string_literal: true
require 'pdf_fill/filler'

describe PdfFill::Filler do
  include SchemaMatchers

  describe '#fill_form' do
    %w(simple kitchen_sink overflow).each do |type|
      context "with #{type} test data" do
        let(:form_data) do
          get_fixture("pdf_fill/21P-527EZ/#{type}")
        end

        it 'should fill the form correctly' do
          form_code = '21P-527EZ'
          expect(form_data.to_json).to match_vets_schema(form_code)

          if type == 'overflow'
            # when pdftk combines files there are random diffs so we can't compare the pdfs like normal
            the_extras_generator = nil

            expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
              the_extras_generator = extras_generator
              old_file_path
            end
          end

          file_path = described_class.fill_form(form_code, form_data)

          if type == 'overflow'
            expect(the_extras_generator.instance_variable_get(:@text)).to eq(
              File.read("spec/fixtures/pdf_fill/21P-527EZ/#{type}.txt")
            )
          end

          expect(
            FileUtils.compare_file(file_path, "spec/fixtures/pdf_fill/21P-527EZ/#{type}.pdf")
          ).to eq(true)

          File.delete(file_path)
        end
      end
    end
  end
end
