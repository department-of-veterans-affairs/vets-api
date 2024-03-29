# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PdfFiller do
  subject(:instance) { described_class.new(form_number:, form:) }

  describe "#generate" do
    subject(:generate) { instance.generate }

    ivc_champva_forms = %w[vha_10_10d vha_10_7959f_1 vha_10_7959f_2]
    other_forms = %w[
      vba_26_4555 vba_26_4555-min vba_21_4142 vba_21_4142-min vba_21_10210 vba_21_10210-min vba_21p_0847
      vba_21p_0847-min vba_21_0972 vba_21_0972-min vba_21_0966 vba_21_0966-min vba_40_0247 vba_40_0247
      vba_40_0247-min vha_10_7959c
    ]
    form_list = ivc_champva_forms + other_forms

    form_list.each do |file_name|
      context 'when filling the pdf given a form' do
        let(:form_number) { file_name.gsub('-min', '') }
        let(:test_payload) { file_name }
        let(:expected_pdf_path) { "tmp/#{form_number}-tmp.pdf" }
        let(:data) { JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{test_payload}.json")) }
        let(:form) { "SimpleFormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(data) }

        before do
          # remove the pdf if it already exists
          FileUtils.rm_f(expected_pdf_path)
          generate
        end

        context 'when a legitimate JSON payload is provided' do
          it 'properly fills out the associated PDF' do
            expect(File.exist?(expected_pdf_path)).to eq(true)
          end

          it 'validates json is parseable' do
            expect do
              JSON.parse(File.read("modules/simple_forms_api/app/form_mappings/#{form_number}.json.erb"))
            end.not_to raise_error
          end
        end
      end
    end
  end
end
