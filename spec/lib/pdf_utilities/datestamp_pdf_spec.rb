# frozen_string_literal: true

require 'rails_helper'
require 'pdf_utilities/datestamp_pdf'

RSpec.describe PDFUtilities::DatestampPdf do
  describe '#run' do
    before do
      @file_path = Common::FileHelpers.random_file_path
      Prawn::Document.generate(@file_path, margin: [0, 0]) do |pdf|
        5.times { pdf.start_new_page }
      end
    end

    let(:opt) do
      { append_to_stamp: 'Confirmation=VETS-XX-1234' }
    end

    let(:instance) do
      described_class.new(@file_path, **opt)
    end

    after do
      Common::FileHelpers.delete_file_if_exists(@file_path)
    end

    context 'with a successful pdf stamp' do
      def assert_pdf_stamp(file, stamp)
        pdf_reader = PDF::Reader.new(file)
        expect(pdf_reader.pages[0].text).to eq(stamp)
        File.delete(file)
      end

      it 'adds text with a datestamp at the given location' do
        Timecop.travel(Time.zone.local(1999, 12, 31, 23, 59, 59)) do
          out_path = instance.run(text: 'Received via vets.gov at', x: 10, y: 10)
          assert_pdf_stamp(out_path, 'Received via vets.gov at 1999-12-31 11:59 PM UTC. Confirmation=VETS-XX-1234')
        end
      end

      it 'takes a timestamp, page number, and template' do
        out_path = instance.run(text: 'Received via vets.gov', x: 10, y: 10, timestamp: Time.zone.now,
                                text_only: true, page_number: 0,
                                template: './lib/pdf_fill/forms/pdfs/686C-674.pdf', multistamp: true)
        pdf_reader = PDF::Reader.new(out_path)
        expect(pdf_reader.pages[0].text).to eq('Received via vets.gov')
        File.delete(out_path)
      end

      it 'takes a timestamp, page number greater than 0, and template' do
        out_path = instance.run(text: 'Received via vets.gov', x: 10, y: 10, timestamp: Time.zone.now,
                                text_only: true, page_number: 5,
                                template: './lib/pdf_fill/forms/pdfs/686C-674.pdf', multistamp: true)
        pdf_reader = PDF::Reader.new(out_path)
        expect(pdf_reader.pages[5].text).to eq('Received via vets.gov')
        File.delete(out_path)
      end

      it 'adds text with a datestamp for all forms except 40-10007 with expected formatting' do
        out_path = instance.run(text: 'Received via vets.gov', x: 10, y: 10, timestamp: Time.zone.local(2024, 1, 30))
        pdf_reader = PDF::Reader.new(out_path)
        expect(pdf_reader.pages[0].text).to eq('Received via vets.gov 2024-01-30 12:00 AM UTC. Confirmation=VETS-XX-1234') # rubocop:disable Layout/LineLength
        File.delete(out_path)
      end

      it 'adds text with a datestamp for form 40-10007 with expected formatting' do
        Timecop.freeze(Time.zone.local(2024, 1, 30)) do
          @file_path = 'tmp/vba_40_10007-stamped.pdf'
          Prawn::Document.new.render_file @file_path
          out_path = instance.run(text: 'Received via vets.gov', x: 10, y: 10, timestamp: Time.zone.local(2024, 1, 30))
          pdf_reader = PDF::Reader.new(out_path)
          expect(pdf_reader.pages[0].text).to eq('Received via vets.gov 01/30/2024. Confirmation=VETS-XX-1234')
          File.delete(out_path)
        end
      end

      context 'with no additional text' do
        let(:opt) do
          {}
        end

        it 'does not include the datetime' do
          text = 'Vets.gov Submission'
          out_path = instance.run(text:, x: 449, y: 730, text_only: true)
          assert_pdf_stamp(out_path, text)
        end
      end
    end

    describe 'error handling' do
      let(:error_message) { 'bad news bears' }

      context 'when an error occurs in #generate_stamp' do
        it 'logs and reraise the error and not call stamp' do
          allow(Prawn::Document).to receive(:generate).and_raise(error_message)
          expect(Rails.logger).to receive(:error).once.with("Failed to generate datestamp file: #{error_message}")
          expect(instance).not_to receive(:stamp_pdf)
          expect do
            instance.run(text: 'Received via vets.gov at', x: 10, y: 10)
          end.to raise_error(StandardError, error_message)
        end
      end

      context 'when an error occurs in #stamp' do
        it 'logs and reraise the error and clean up after itself' do
          allow(PDFUtilities::PDFTK).to receive(:stamp).and_raise(error_message)
          expect(File).to receive(:delete).twice.and_call_original
          expect do
            instance.run(text: 'Received via vets.gov at', x: 10, y: 10)
          end.to raise_error(StandardError, error_message)
        end
      end
    end
  end
end
