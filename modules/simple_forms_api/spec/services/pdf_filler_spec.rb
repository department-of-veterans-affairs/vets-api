# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PdfFiller do
  forms = %w[
    vba_21_0966
    vba_21_0966-min
    vba_21_0972
    vba_21_0972-min
    vba_21_10210
    vba_21_10210-min
    vba_21_4138-min
    vba_21_4142
    vba_21_4142-min
    vba_21p_0847
    vba_21p_0847-min
    vba_26_4555
    vba_26_4555-min
    vba_40_0247
    vba_40_0247-min
    vba_40_1330m
    vba_40_1330m-min
  ]

  describe '#initialize' do
    context 'when the filler is instantiated without a form_number' do
      it 'throws an error' do
        form_number = forms.first
        data = JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{form_number}.json"))
        form = "SimpleFormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
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
        let(:pseudorandom_value) { 'abc123' }
        let(:expected_pdf_path) { Rails.root.join("tmp/#{name}-#{pseudorandom_value}-tmp.pdf") }
        let(:expected_stamped_path) { Rails.root.join("tmp/#{name}-#{pseudorandom_value}-stamped.pdf") }
        let(:data) { JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{file_name}.json")) }
        let(:form) { "SimpleFormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(data) }
        let(:name) { SecureRandom.hex }

        before { allow(SecureRandom).to receive(:hex).and_return(pseudorandom_value) }

        after do
          FileUtils.rm_f(expected_pdf_path)
          FileUtils.rm_f(expected_stamped_path)
        end

        context 'when a legitimate JSON payload is provided' do
          it 'properly fills out the associated PDF' do
            expect do
              described_class.new(form_number:, form:, name:).generate
            end.to change { File.exist?(expected_pdf_path) }.from(false).to(true)
          end

          it 'uses a temporary file to initialize a stampable template file' do
            allow(FileUtils).to receive(:copy_file).and_call_original

            described_class.new(form_number:, form:, name:).generate

            expect(FileUtils).to have_received(:copy_file).with(anything, expected_stamped_path.to_s)
          end
        end
      end
    end

    context 'when mapping the pdf data for vba_21_4138 with overflow remarks' do
      let(:form_number) { 'vba_21_4138' }
      let(:pseudorandom_value) { 'abc123' }
      let(:name) { SecureRandom.hex }
      let(:expected_pdf_path) { Rails.root.join("tmp/#{name}-#{pseudorandom_value}-tmp.pdf") }
      let(:expected_stamped_path) { Rails.root.join("tmp/#{name}-#{pseudorandom_value}-stamped.pdf") }
      let(:data) { JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{form_number}.json")) }
      let(:form) { SimpleFormsApi::VBA214138.new(data) }

      before do
        allow(SecureRandom).to receive(:hex).and_return(pseudorandom_value)
        data['statement'] = 'x' * (SimpleFormsApi::VBA214138::ALLOTTED_REMARKS_LAST_INDEX + 2)
        allow(FileUtils).to receive(:copy_file).and_call_original
        allow(PdfFill::Filler).to receive(:merge_pdfs).and_call_original
      end

      after do
        FileUtils.rm_f(expected_pdf_path)
        FileUtils.rm_f(expected_stamped_path)
        FileUtils.rm_f(@result_path) if @result_path
      end

      it 'merges an overflow page and returns a stamped final PDF; base tmp is cleaned up' do
        @result_path = described_class.new(form_number:, form:, name:).generate

        expect(PdfFill::Filler).to have_received(:merge_pdfs)

        expect(File.exist?(expected_pdf_path)).to be(false)

        expect(@result_path).to be_a(String)
        expect(File.exist?(@result_path)).to be(true)

        expect(FileUtils).to have_received(:copy_file).with(anything, expected_stamped_path.to_s)
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
      form_name = form_number.gsub('-min', '')
      data = JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{form_name}.json"))
      form = "SimpleFormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(data) # Used in ERB binding
      erb_content = File.read("modules/simple_forms_api/app/form_mappings/#{form_number}.json.erb")
      rendered_erb = ERB.new(erb_content).result(binding) # Rendering as ERB strips out comments
      JSON.parse(rendered_erb)
    end
  end
end
