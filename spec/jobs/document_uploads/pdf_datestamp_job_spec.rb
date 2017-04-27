# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DocumentUploads::PdfDatestampJob do
  describe '#perform' do
    before(:all) do
      @file_path = Rails.root.join('spec/fixtures/files/stamp_pdf_1_page.pdf')
      Prawn::Document.new.render_file @file_path
    end

    context 'with a succesful pdf stamp' do
      it 'should add text with a datestamp at the given location' do
        Timecop.travel(Time.zone.local(1999, 12, 31, 23, 59, 59)) do
          subject.perform(@file_path, 'Received via vets.gov at', 0, 0)
          text_analysis = PDF::Inspector::Text.analyze(@file_path)
          expect(text_analysis.strings.first).to eq('Received via vets.gov at 1999-12-31T23:59:59+00:00')
        end
      end
    end

    describe 'error handling' do
      let(:error_message) { 'bad news bears' }

      context 'when an error occurs in #generate_stamp' do
        it 'should log and reraise the error and not call stamp' do
          allow(Prawn::Document).to receive(:generate).and_raise(error_message)
          expect(Rails.logger).to receive(:error).once.with("Failed to generate datestamp file: #{error_message}")
          expect(subject).not_to receive(:stamp)
          expect do
            subject.perform(@file_path, 'Received via vets.gov at', 0, 0)
          end.to raise_error(StandardError, error_message)
        end
      end

      context 'when an error occurs in #stamp' do
        it 'should log and reraise the error and clean up after itself' do
          allow(CombinePDF).to receive(:load).and_raise(error_message)
          expect(Rails.logger).to receive(:error).once.with("Failed to datestamp PDF file: #{error_message}")
          expect(File).to receive(:delete).once
          expect do
            subject.perform(@file_path, 'Received via vets.gov at', 0, 0)
          end.to raise_error(StandardError, error_message)
        end
      end
    end

    after(:all) do
      File.delete(@file_path) if File.exist? @file_path
    end
  end
end
