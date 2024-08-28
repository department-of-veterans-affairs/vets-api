# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PdfStamper do
  let(:data) { JSON.parse(File.read('modules/simple_forms_api/spec/fixtures/form_json/vba_21_0845.json')) }
  let(:form) { SimpleFormsApi::VBA210845.new(data) }
  let(:path) { 'tmp/template.pdf' }
  let(:instance) { described_class.new(path, form, 3) }

  describe '#stamp_pdf' do
    context 'applying stamps as specified by the form model' do
      context 'page is specified' do
        let(:coords) { {} }
        let(:page) { 2 }
        let(:desired_stamp) { { coords:, page: } }
        let(:page_configuration) { double }

        before do
          allow(form).to receive_messages(desired_stamps: [desired_stamp], submission_date_stamps: [])
          allow(instance).to receive(:verified_multistamp)
          allow(instance).to receive(:verify)
          allow(instance).to receive(:get_page_configuration).and_return(page_configuration)
        end

        it 'calls #get_page_configuration' do
          instance.stamp_pdf

          expect(instance).to have_received(:get_page_configuration).with(desired_stamp)
        end

        it 'calls #verified_multistamp' do
          instance.stamp_pdf

          expect(instance).to have_received(:verified_multistamp).with(desired_stamp, page_configuration)
        end
      end

      context 'page is not specified' do
        let(:desired_stamp) { { coords: {} } }
        let(:current_file_path) { 'current-file-path' }
        let(:datestamp_instance) { double(run: current_file_path) }

        before do
          allow(form).to receive_messages(desired_stamps: [desired_stamp], submission_date_stamps: [])
          allow(File).to receive(:rename)
          allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_instance)
          allow(instance).to receive(:verify)
        end

        it 'calls PDFUtilities::DatestampPdf and renames the File' do
          instance.stamp_pdf

          expect(File).to have_received(:rename).with(current_file_path, path)
        end
      end
    end

    describe 'stamping the authentication text' do
      let(:current_file_path) { 'current-file-path' }
      let(:datestamp_instance) { double(run: current_file_path) }

      before do
        allow(form).to receive_messages(desired_stamps: [], submission_date_stamps: [])
        allow(instance).to receive(:verify).and_yield
        allow(File).to receive(:rename)
        allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_instance)
      end

      it 'calls PDFUtilities::DatestampPdf and renames the File' do
        text = /Signed electronically and submitted via VA.gov at /
        instance.stamp_pdf

        expect(datestamp_instance).to have_received(:run).with(text:, x: anything, y: anything, text_only: false,
                                                               size: 9)
        expect(File).to have_received(:rename).with(current_file_path, path)
      end
    end
  end
end
