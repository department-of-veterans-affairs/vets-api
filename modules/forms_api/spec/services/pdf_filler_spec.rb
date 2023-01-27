# frozen_string_literal: true

require 'rails_helper'
require FormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe FormsApi::PdfFiller do
  describe 'test pdf fill' do
    it 'fills out a PDF from a templated JSON file' do
      form_number = 'vha_10_10d'
      expected_pdf_path = "tmp/#{form_number}-tmp.pdf"

      # remove the pdf if it already exists
      FileUtils.rm_f(expected_pdf_path)

      # fill the PDF
      data = JSON.parse(File.read("modules/forms_api/spec/fixtures/form_json/#{form_number}.json"))
      filler = FormsApi::PdfFiller.new(form_number: form_number, data: data)
      filler.generate
      expect(File.exist?(expected_pdf_path)).to eq(true)
    end

    it 'validate valid json' do
      # inspect the contents that will be loaded into the PDF
      expect do
        JSON.parse(File.read('modules/forms_api/app/form_mappings/vha_10_10d.json.erb'))
      end.not_to raise_error(IOError)
      # passes if JSON.parse does not throw an error
    end
  end
end
