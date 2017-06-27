require 'spec_helper'
# frozen_string_literal: true
require 'pdf_fill/filler'

describe PdfFill::Filler do
  include SchemaMatchers

  describe '#combine_extras' do
    let(:extras_generator) { double }

    subject do
      described_class.combine_extras('file_path', extras_generator)
    end

    context 'when extras_generator doesnt have text' do
      it 'should return the old_file_path' do
        expect(extras_generator).to receive(:text?).once.and_return(false)

        expect(subject).to eq('file_path')
      end
    end

    context 'when extras_generator has text' do
      before do
        expect(extras_generator).to receive(:text?).once.and_return(true)
      end

      it 'should generate extras and combine the files', run_at: '2016-12-31 00:00:00 EDT' do
        file_path = 'tmp/pdfs/form_2016-12-31 04:00:00 UTC_final.pdf'
        expect(extras_generator).to receive(:generate).once.and_return('extras.pdf')
        expect(described_class::PDF_FORMS).to receive(:cat).once.with(
          'file_path',
          'extras.pdf',
          file_path
        )
        expect(File).to receive(:delete).once.with('extras.pdf')
        expect(File).to receive(:delete).once.with('file_path')

        expect(subject).to eq(file_path)
      end
    end
  end

  describe '#fill_form' do
    def simplify_fields(fields)
      fields.map do |field|
        {
          name: field.name,
          value: field.value
        }
      end
    end

    def compare_pdfs(pdf1, pdf2)
      fields = []
      [pdf1, pdf2].each do |pdf|
        fields << simplify_fields(described_class::PDF_FORMS.get_fields(pdf))
      end

      fields[0] == fields[1]
    end

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
            extras_path = the_extras_generator.generate
            expect(
              FileUtils.compare_file(extras_path, 'spec/fixtures/pdf_fill/21P-527EZ/overflow_extras.pdf')
            ).to eq(true)

            File.delete(extras_path)
          end

          expect(
            compare_pdfs(file_path, "spec/fixtures/pdf_fill/21P-527EZ/#{type}.pdf")
          ).to eq(true)

          File.delete(file_path)
        end
      end
    end
  end
end
