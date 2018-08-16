# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/hash_converter'

PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)

def basic_class
    PdfFill::Forms::Va21p4142.new({})
end

describe PdfFill::Forms::Va21p4142 do
    let(:form_data) do
      {}
    end
  
    let(:new_form_class) do
      described_class.new(form_data)
    end
  
    def class_form_data
      new_form_class.instance_variable_get(:@form_data)
    end

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
    
    def fill_form(type, f_data)
        code = '21P-4142'
        form_class = described_class
        folder = 'tmp/pdfs'
        FileUtils.mkdir_p(folder)
        file_path = "#{folder}/#{code}_#{type}_temp.pdf"
        hash_converter = HashConverter.new(form_class.date_strftime)
        new_hash = hash_converter.transform_data(
          form_data: form_class.new(f_data).merge_fields,
          pdftk_keys: form_class::KEY
        )
  
        PDF_FORMS.fill_form(
          "lib/pdf_fill/forms/pdfs/#{code}.pdf",
          file_path,
          new_hash,
          flatten: Rails.env.production?
        )
        
        file_path
        # combine_extras(file_path, hash_converter.extras_generator)
      end

    describe '#merge_fields' do
        it 'should merge the right fields', run_at: '2016-12-31 00:00:00 EDT' do
        expect(described_class.new(get_fixture('pdf_fill/21P-4142/kitchen_sink')).merge_fields).to eq(
            get_fixture('pdf_fill/21P-4142/merge_fields'))
        end
    end
    
    describe '#fill_form', run_at: '2017-07-25 00:00:00 -0400' do

        %w[simple kitchen_sink overflow].each do |type|
            context "with #{type} test data" do
                let(:form_data) do
                    get_fixture("pdf_fill/21P-4142/#{type}")
                end
                it 'should fill the form correctly' do
                    file path = fill_form(type, form_data)

                    expect(
                    FileUtils.compare_file(file_path, "spec/fixtures/pdf_fill/#{type}.pdf")
                    ).to eq(true)
                    
                    binding.pry

                    File.delete(file_path)
                end
            end
        end
    end
end

