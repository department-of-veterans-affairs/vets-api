# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/filler'

describe PdfFill::Filler do
  describe '#fill_form' do
    %w(simple kitchen_sink).each do |type|
      context "with #{type} test data" do
        let(:form_data) do
          get_fixture("pdf_fill/21P-527EZ/#{type}")
        end

        it 'should fill the form correctly' do
          form_code = '21P-527EZ'
          expect(form_data.to_json).to match_vets_schema(form_code)
          file_path = described_class.fill_form(form_code, form_data)

          expect(
            FileUtils.compare_file(file_path, "spec/fixtures/pdf_fill/21P-527EZ/#{type}.pdf")
          ).to eq(true)

          File.delete(file_path)
        end
      end
    end
  end
end
