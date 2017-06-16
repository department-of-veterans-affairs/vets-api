require 'spec_helper'
# frozen_string_literal: true
require 'pdf_fill/filler'

describe PdfFill::Filler do
  include SchemaMatchers

  describe '#combine_extras' do
    let(:extras_generator) { double }
    context 'when extras_generator has text' do
      before do
        expect(extras_generator).to receive(:has_text).once.and_return(true)
      end

      it 'should generate extras and combine the files', run_at: '2016-12-31 00:00:00 EDT' do
        expect(extras_generator).to receive(:generate).once.and_return('extras.pdf')
        expect(described_class::PDF_FORMS).to receive(:cat).once.with(
          'file_path',
          'extras.pdf',
          'tmp/pdfs/form_2016-12-31 04:00:00 UTC_final.pdf'
        )
        expect(File).to receive(:delete).once.with('extras.pdf')
        expect(File).to receive(:delete).once.with('file_path')

        described_class.combine_extras('file_path', extras_generator)
      end
    end
  end

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
