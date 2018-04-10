require 'rails_helper'
# frozen_string_literal: true

describe PdfFill::Filler do
  include SchemaMatchers

  describe '#combine_extras' do
    let(:extras_generator) { double }
    let(:old_file_path) { 'tmp/pdfs/file_path.pdf' }

    subject do
      described_class.combine_extras(old_file_path, extras_generator)
    end

    context 'when extras_generator doesnt have text' do
      it 'should return the old_file_path' do
        expect(extras_generator).to receive(:text?).once.and_return(false)

        expect(subject).to eq(old_file_path)
      end
    end

    context 'when extras_generator has text' do
      before do
        expect(extras_generator).to receive(:text?).once.and_return(true)
      end

      it 'should generate extras and combine the files' do
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

  describe '#fill_form', run_at: '2017-07-25 00:00:00 -0400' do
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
      p fields

      fields[0] == fields[1]
    end

    %w[21P-527EZ 21P-530].each do |form_id|
      context "form #{form_id}" do
        %w[simple kitchen_sink overflow].each do |type|
          context "with #{type} test data" do
            let(:form_data) do
              get_fixture("pdf_fill/#{form_id}/#{type}")
            end

            it 'should fill the form correctly' do
              fact_name = form_id == '21P-527EZ' ? :pension_claim : :burial_claim
              saved_claim = create(fact_name, form: form_data.to_json)

              if type == 'overflow'
                # compare_pdfs only compares based on filled fields, it doesn't read the extras page
                the_extras_generator = nil

                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              file_path = described_class.fill_form(saved_claim)

              if type == 'overflow'
                extras_path = the_extras_generator.generate
                expect(
                  FileUtils.compare_file(extras_path, "spec/fixtures/pdf_fill/#{form_id}/overflow_extras.pdf")
                ).to eq(true)

                File.delete(extras_path)
              end

              expect(
                compare_pdfs(file_path, "spec/fixtures/pdf_fill/#{form_id}/#{type}")
              ).to eq(true)

              File.delete(file_path)
            end
          end
        end
      end
    end
  end
end
