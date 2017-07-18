# frozen_string_literal: true
require 'rails_helper'
require 'workflow/task/shared/datestamp_pdf_task'

RSpec.describe Workflow::Task::Shared::DatestampPdfTask do
  describe '#run' do
    before(:all) do
      @file_path = Rails.root.join('spec', 'fixtures', 'files', 'stamp_pdf_1_page.pdf')
      Prawn::Document.new.render_file @file_path
    end

    let(:attacher) do
      a = Shrine::Attacher.new(InternalAttachment.new, :file)
      a.assign(File.open(@file_path))
      a
    end

    let(:instance) do
      described_class.new({ append_to_stamp: 'Confirmation=VETS-XX-1234' }, internal: { file: attacher.read })
    end

    context 'with a succesful pdf stamp' do
      def assert_pdf_stamp(stamp)
        text_analysis = PDF::Inspector::Text.analyze(instance.file.read)
        expect(text_analysis.strings.first).to eq(stamp)
      end

      it 'should add text with a datestamp at the given location' do
        Timecop.travel(Time.zone.local(1999, 12, 31, 23, 59, 59)) do
          instance.run(text: 'Received via vets.gov at', x: 10, y: 10)
          assert_pdf_stamp('Received via vets.gov at 1999-12-31T23:59:59+00:00. Confirmation=VETS-XX-1234')
        end
      end

      context 'with no additional text' do
        it 'should add just the text' do
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
          allow(CombinePDF).to receive(:load).and_raise(error_message)
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
