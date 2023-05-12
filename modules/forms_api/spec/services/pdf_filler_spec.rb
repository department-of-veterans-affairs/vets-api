# frozen_string_literal: true

require 'rails_helper'
require FormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe FormsApi::PdfFiller do
  def self.test_pdf_fill(form_number, test_payload = form_number)
    it 'fills out a PDF from a templated JSON file' do
      expected_pdf_path = "tmp/#{form_number}-tmp.pdf"

      # remove the pdf if it already exists
      FileUtils.rm_f(expected_pdf_path)

      # fill the PDF
      data = JSON.parse(File.read("modules/forms_api/spec/fixtures/form_json/#{test_payload}.json"))
      filler = FormsApi::PdfFiller.new(form_number:, data:)
      filler.generate
      expect(File.exist?(expected_pdf_path)).to eq(true)
    end
  end

  test_pdf_fill 'vha_10_10d'
  test_pdf_fill 'vba_26_4555'
  test_pdf_fill 'vba_26_4555', 'vba_26_4555-min'
  test_pdf_fill 'vba_21_4142'
  test_pdf_fill 'vba_21_4142', 'vba_21_4142-min'
  test_pdf_fill 'vba_21_10210'
  test_pdf_fill 'vba_21_10210', 'vba_21_10210-min'

  def self.test_json_valid(mapping_file)
    it 'validates json is parseable' do
      expect do
        JSON.parse(File.read("modules/forms_api/app/form_mappings/#{mapping_file}"))
      end.not_to raise_error
    end
  end

  test_json_valid 'vba_26_4555.json.erb'
  test_json_valid 'vha_10_10d.json.erb'
  test_json_valid 'vba_21_4142.json.erb'
  test_json_valid 'vba_21_10210.json.erb'
end
