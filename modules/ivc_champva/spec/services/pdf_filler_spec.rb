# frozen_string_literal: true

require 'rails_helper'
require IvcChampva::Engine.root.join('spec', 'spec_helper.rb')

describe IvcChampva::PdfFiller do
  def self.test_pdf_fill(form_number, test_payload = form_number)
    form_name = form_number.split(Regexp.union(%w[vba_ vha_]))[1].gsub('_', '-')
    context "when filling the pdf for form #{form_name} given template #{test_payload}" do
      it 'fills out a PDF from a templated JSON file' do
        expected_pdf_path = "tmp/#{form_number}-tmp.pdf"

        # remove the pdf if it already exists
        FileUtils.rm_f(expected_pdf_path)

        # fill the PDF
        data = JSON.parse(File.read("modules/ivc_champva/spec/fixtures/form_json/#{test_payload}.json"))
        form = "IvcChampva::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
        filler = IvcChampva::PdfFiller.new(form_number:, form:)
        filler.generate
        expect(File.exist?(expected_pdf_path)).to eq(true)
      end
    end
  end

  test_pdf_fill 'vha_10_10d'
  test_pdf_fill 'vha_10_7959f_1'
  test_pdf_fill 'vha_10_7959f_2'

  def self.test_json_valid(mapping_file)
    it 'validates json is parseable' do
      expect do
        JSON.parse(File.read("modules/ivc_champva/app/form_mappings/#{mapping_file}"))
      end.not_to raise_error
    end
  end

  test_json_valid 'vha_10_10d.json.erb'
  test_json_valid 'vha_10_7959f_1.json.erb'
  test_json_valid 'vha_10_7959f_2.json.erb'
end
