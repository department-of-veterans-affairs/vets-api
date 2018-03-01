# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionBurial::DatestampPdf do
  describe '#run' do
    before(:all) do
      @file_path = Rails.root.join('spec', 'fixtures', 'files', 'stamp_pdf_1_page.pdf')
      Prawn::Document.new.render_file @file_path
    end

    let(:attacher) do
      a = Shrine::Attacher.new(InternalAttachment.new, :file)
      file = File.open(@file_path)
      a.assign(file)
      a
    end

    let(:instance) do
      described_class.new(File.open(@file_path), append_to_stamp: 'Confirmation=VETS-XX-1234')
    end

    context 'with a succesful pdf stamp' do
      def assert_pdf_stamp(file, stamp)
        pdf_reader = PDF::Reader.new(file)
        expect(pdf_reader.pages[0].text).to eq(stamp)
        File.delete(file)
      end

      it 'should add text with a datestamp at the given location' do
        Timecop.travel(Time.zone.local(1999, 12, 31, 23, 59, 59)) do
          out_path = instance.run(text: 'Received via vets.gov at', x: 10, y: 10)
          assert_pdf_stamp(out_path, 'Received via vets.gov at 1999-12-31. Confirmation=VETS-XX-1234')
        end
      end

      context 'with no additional text' do
        let(:instance) do
          described_class.new({}, internal: { file: attacher.read })
        end

        it 'does not include the datetime' do
          text = 'Vets.gov Submission'
          instance.run(text: text, x: 449, y: 730, text_only: true)
          assert_pdf_stamp(text)
        end
      end
    end

    describe 'error handling' do
      let(:error_message) { 'bad news bears' }

      context 'when an error occurs in #generate_stamp' do
        it 'should log and reraise the error and not call stamp' do
          allow(Prawn::Document).to receive(:generate).and_raise(error_message)
          expect(Rails.logger).to receive(:error).once.with("Failed to generate datestamp file: #{error_message}")
          expect(instance).not_to receive(:stamp)
          expect do
            instance.run(text: 'Received via vets.gov at', x: 10, y: 10)
          end.to raise_error(StandardError, error_message)
        end
      end

      context 'when an error occurs in #stamp' do
        it 'should log and reraise the error and clean up after itself' do
          allow(PdfFill::Filler::PDF_FORMS).to receive(:stamp).and_raise(error_message)
          expect(Rails.logger).to receive(:error).once.with("Failed to datestamp PDF file: #{error_message}")
          expect(File).to receive(:delete).once.and_call_original
          expect do
            instance.run(text: 'Received via vets.gov at', x: 10, y: 10)
          end.to raise_error(StandardError, error_message)
        end
      end
    end

    after(:all) do
      File.delete(@file_path) if File.exist? @file_path
    end
  end
end
