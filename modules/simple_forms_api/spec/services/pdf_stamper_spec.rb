# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PdfStamper do
  form_numbers = SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP.values

  describe '#stamp_pdf' do
    let(:datestamp_instance) { instance_double(PDFUtilities::DatestampPdf) }
    let(:current_file_path) { 'current-file-path' }

    before do
      allow(instance).to receive(:verify).and_call_original
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_instance)
      allow(datestamp_instance).to receive(:run).and_return(current_file_path)
      allow(File).to receive_messages(rename: true, exist?: true)
      allow(File).to receive(:size).and_return(0, 1)
    end

    context 'when the form is specified' do
      form_numbers.each do |form_number|
        context "for form #{form_number}" do
          let(:data) do
            JSON.parse(File.read("modules/simple_forms_api/spec/fixtures/form_json/#{form_number}.json"))
          end
          let(:form) { "SimpleFormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(data) }
          let(:stamped_template_path) do
            'modules/simple_forms_api/spec/fixtures/pdfs/vba_21_0779-completed.pdf'
          end
          let(:timestamp) { nil }
          let(:current_loa) { 3 }
          let(:instance) { described_class.new(stamped_template_path:, form:, current_loa:, timestamp:) }

          context 'applying stamps as specified by the form model' do
            context 'page is specified' do
              let(:coords) { {} }
              let(:page) { 2 }
              let(:desired_stamp) { { coords:, page: } }
              let(:page_configuration) { double }

              before do
                allow(form).to receive_messages(desired_stamps: [desired_stamp], submission_date_stamps: [])
                allow(instance).to receive(:verified_multistamp)
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

              context 'timestamp is passed in' do
                let(:timestamp) { 'right-timestamp' }

                it 'passes the right timestamp when fetching the submission date stamps' do
                  instance.stamp_pdf

                  expect(form).to have_received(:submission_date_stamps).with(timestamp)
                end
              end
            end

            context 'page is not specified' do
              let(:desired_stamp) { { coords: {} } }

              before do
                allow(form).to receive_messages(desired_stamps: [desired_stamp], submission_date_stamps: [])
              end

              it 'calls PDFUtilities::DatestampPdf and renames the File and then cleans up' do
                instance.stamp_pdf

                # This is called once for `#stamp_all_pages` and once for `#multistamp_cleanup`
                expect(File).to have_received(:rename).with(current_file_path, stamped_template_path).twice
              end
            end

            context 'form is not specified' do
              let(:form) { nil }

              it 'does not call stamp_form' do
                allow(instance).to receive(:stamp_form)

                instance.stamp_pdf

                expect(instance).not_to have_received(:stamp_form)
              end
            end
          end

          describe 'stamping the authentication text' do
            let(:current_file_path) { 'current-file-path' }

            before do
              allow(form).to receive_messages(desired_stamps: [], submission_date_stamps: [])
            end

            it 'calls PDFUtilities::DatestampPdf and renames the File' do
              text = /Signed electronically and submitted via VA.gov at /
              instance.stamp_pdf

              expect(datestamp_instance).to have_received(:run).with(
                text:, x: anything, y: anything, text_only: false, size: 9, timestamp: anything
              )
              expect(File).to have_received(:rename).with(current_file_path, stamped_template_path)
            end

            context 'timestamp is passed in' do
              let(:timestamp) { 'fake-timestamp' }

              it 'calls PDFUtilities::DatestampPdf with the timestamp' do
                text = /Signed electronically and submitted via VA.gov at /
                instance.stamp_pdf

                expect(datestamp_instance).to(
                  have_received(:run).with(
                    text:, x: anything, y: anything, text_only: false, size: 9, timestamp:
                  )
                )
              end
            end
          end
        end
      end
    end

    context 'when the form is not specified' do
      PersistentAttachments::VAForm::CONFIGS.keys.map(&:downcase).each do |form_number|
        context "for form #{form_number}" do
          let(:form_id) { "vba_#{form_number.gsub('-', '_')}" }
          let(:stamped_template_path) do
            "modules/simple_forms_api/spec/fixtures/pdfs/#{form_id}-completed.pdf"
          end
          let(:current_file_path) { 'current-file-path' }
          let(:instance) do
            described_class.new(stamped_template_path:, current_loa: 3, timestamp: Time.current)
          end

          context 'applying stamps as specified by the form model' do
            context 'page is specified' do
              before do
                allow(instance).to receive(:verified_multistamp)
                allow(instance).to receive(:get_page_configuration)
              end

              it 'calls the Datestamp PDF service' do
                instance.stamp_pdf

                expect(datestamp_instance).to have_received(:run)
              end

              it 'renames the file' do
                instance.stamp_pdf

                expect(File).to have_received(:rename).with(current_file_path, stamped_template_path)
              end

              it 'verifies the file size' do
                instance.stamp_pdf

                expect(File).to have_received(:exist?).with(stamped_template_path)
                expect(File).to have_received(:size).with(stamped_template_path).twice
              end
            end
          end
        end
      end
    end
  end
end
