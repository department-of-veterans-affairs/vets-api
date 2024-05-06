# frozen_string_literal: true

require 'rails_helper'
require IvcChampva::Engine.root.join('spec', 'spec_helper.rb')

describe IvcChampva::PdfFiller do
  %w[vha_10_10d vha_10_7959f_1 vha_10_7959f_2].each do |form_number|
    form_name = form_number.split(Regexp.union(%w[vba_ vha_]))[1].gsub('_', '-')
    context "when filling the pdf for form #{form_name} given template #{form_number}" do
      let(:expected_pdf_path) { "tmp/#{name}-tmp.pdf" }
      let(:name) { SecureRandom.hex }
      let(:data) { JSON.parse(File.read("modules/ivc_champva/spec/fixtures/form_json/#{form_number}.json")) }
      let(:form) { "IvcChampva::#{form_number.titleize.gsub(' ', '')}".constantize.new(data) }

      after { FileUtils.rm_f(expected_pdf_path) }

      it 'fills out a PDF from a templated JSON file' do
        expect do
          IvcChampva::PdfFiller.new(form_number:, form:, name:).generate
        end.to change { File.exist?(expected_pdf_path) }.from(false).to(true)
      end
    end
  end

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
