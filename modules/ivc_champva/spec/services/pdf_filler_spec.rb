# frozen_string_literal: true

require 'rails_helper'
require IvcChampva::Engine.root.join('spec', 'support', 'pdf_matcher.rb')
require IvcChampva::Engine.root.join('spec', 'spec_helper.rb')
require IvcChampva::Engine.root.join('app', 'services', 'ivc_champva', 'pdf_stamper')

describe IvcChampva::PdfFiller do
  forms = %w[vha_10_10d vha_10_7959f_1 vha_10_7959f_2 vha_10_7959c]

  describe '#initialize' do
    context 'when the filler is instantiated without a form_number' do
      it 'throws an error' do
        form_number = forms.first
        file_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', "#{form_number}.json")
        expect(File.exist?(file_path)).to be(true), "Fixture file not found: #{file_path}"
        data = JSON.parse(File.read(file_path))
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
    context 'when the stamped template file exists' do
      it 'generates the form correctly' do
        form_number = forms.first
        uuid = 'eb8ec19d-3934-48c7-b878-dca41c6cd534'
        file_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', "#{form_number}.json")
        expect(File.exist?(file_path)).to be(true), "Fixture file not found: #{file_path}"
        data = JSON.parse(File.read(file_path))
        form = "IvcChampva::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
        pdf_filler = described_class.new(form_number:, form:, uuid:)

        allow(File).to receive(:exist?).and_return(true)
        allow(IvcChampva::PdfStamper).to receive(:stamp_pdf)
        allow(PdfForms).to receive(:new).and_return(double(fill_form: true))
        allow(Common::FileHelpers).to receive(:delete_file_if_exists)

        expect(pdf_filler.generate).to match(%r{tmp/#{uuid}_#{form_number}-tmp\.pdf})
      end
    end

    context 'when the stamped template file does not exist' do
      it 'raises an error' do
        form_number = forms.first
        file_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', "#{form_number}.json")
        expect(File.exist?(file_path)).to be(true), "Fixture file not found: #{file_path}"
        data = JSON.parse(File.read(file_path))
        form = "IvcChampva::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
        pdf_filler = described_class.new(form_number:, form:)

        allow(File).to receive(:exist?).and_return(false)

        expect { pdf_filler.generate }.to raise_error(RuntimeError, /stamped template file does not exist/)
      end
    end

    context 'when generating the form path' do
      it 'ensures the generated form path is in the correct format' do
        form_number = forms.first
        uuid = 'b912b331-4c98-4816-bab9-01aa549e4a5c'
        file_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', "#{form_number}.json")
        expect(File.exist?(file_path)).to be(true), "Fixture file not found: #{file_path}"
        data = JSON.parse(File.read(file_path))
        form = "IvcChampva::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
        pdf_filler = described_class.new(form_number:, form:, uuid:)

        allow(File).to receive(:exist?).and_return(true)
        allow(IvcChampva::PdfStamper).to receive(:stamp_pdf)
        allow(PdfForms).to receive(:new).and_return(double(fill_form: true))
        allow(Common::FileHelpers).to receive(:delete_file_if_exists)

        expect(pdf_filler.generate).to match(%r{tmp/#{uuid}_#{form_number}-tmp\.pdf})
      end
    end
  end

  describe '#create_tempfile' do
    context 'when creating a tempfile' do
      it 'creates and copies the template form correctly' do
        form_number = forms.first
        file_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', "#{form_number}.json")
        expect(File.exist?(file_path)).to be(true), "Fixture file not found: #{file_path}"
        data = JSON.parse(File.read(file_path))
        form = "IvcChampva::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
        pdf_filler = described_class.new(form_number:, form:)

        template_path = "#{IvcChampva::PdfFiller::TEMPLATE_BASE}/#{form_number}.pdf"
        tempfile = double('Tempfile')

        allow(Tempfile).to receive(:new).and_return(tempfile)
        allow(IO).to receive(:copy_stream)
        # Allow both close and flush to be called on the tempfile
        allow(tempfile).to receive(:close)
        allow(tempfile).to receive(:flush)

        expect(IO).to receive(:copy_stream).with(template_path, tempfile)
        expect(tempfile).to receive(:flush) # This is the new line for testing flush
        pdf_filler.create_tempfile
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
