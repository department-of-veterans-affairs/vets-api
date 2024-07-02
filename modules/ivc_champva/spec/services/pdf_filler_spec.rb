# frozen_string_literal: true

require 'rails_helper'
require IvcChampva::Engine.root.join('spec', 'spec_helper.rb')

describe IvcChampva::PdfFiller do
  forms = %w[vha_10_10d vha_10_7959f_1 vha_10_7959f_2]

  describe '#initialize' do
    context 'when the filler is instantiated without a form_number' do
      it 'throws an error' do
        form_number = forms.first
        data = JSON.parse(File.read("modules/ivc_champva/spec/fixtures/form_json/#{form_number}.json"))
        form = "IvcChampva::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
        expect do
          described_class.new(form_number: nil, form:)
        end.to raise_error(RuntimeError, 'form_number is required')
      end
    end

    context 'when the filler is instantiated without a form' do
      it 'throws an error' do
        form_number = forms.first
        expect do
          described_class.new(form_number:, form: nil)
        end.to raise_error(RuntimeError, 'form needs a data attribute')
      end
    end
  end

  describe '#generate' do
    forms.each do |file_name|
      context "when mapping the pdf data given JSON file: #{file_name}" do
        let(:form_number) { file_name.gsub('-min', '') }
        let(:expected_pdf_path) { "tmp/#{name}-tmp.pdf" }
        let(:data) { JSON.parse(File.read("modules/ivc_champva/spec/fixtures/form_json/#{file_name}.json")) }
        let(:form) { "IvcChampva::#{form_number.titleize.gsub(' ', '')}".constantize.new(data) }
        let(:name) { SecureRandom.hex }

        after { FileUtils.rm_f(expected_pdf_path) }

        context 'when a legitimate JSON payload is provided' do
          it 'properly fills out the associated PDF' do
            expect do
              described_class.new(form_number:, form:, name:).generate
            end.to change { File.exist?(expected_pdf_path) }.from(false).to(true)
          end
        end
      end
    end
  end

  describe 'form mappings' do
    list = forms.map { |f| f.gsub('-min', '') }.uniq
    list.each do |file_name|
      context "when mapping #{file_name} input" do
        it 'successfully parses resulting JSON' do
          expect { read_form_mapping(file_name) }.not_to raise_error
        end
      end
    end

    def read_form_mapping(form_number)
      test_file = File.read("modules/ivc_champva/app/form_mappings/#{form_number}.json.erb")
      JSON.parse(test_file)
    end
  end
end
