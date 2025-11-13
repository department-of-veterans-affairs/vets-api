# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::PdfStamper do
  form_numbers = SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP.values

  describe '#stamp_pdf' do
    context 'when the form is specified' do
      let(:datestamp_instance) { instance_double(PDFUtilities::DatestampPdf) }
      let(:current_file_path) { 'current-file-path' }
      let(:current_loa) { 3 }

      before do
        allow(instance).to receive(:verify).and_call_original
        allow(File).to receive_messages(rename: true, exist?: true)
        allow(File).to receive(:size).and_return(0, 1)
      end

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
          let(:instance) { described_class.new(stamped_template_path:, form:, current_loa:, timestamp:) }

          before do
            allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_instance)
            allow(datestamp_instance).to receive(:run).and_return(current_file_path)
          end

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

            context 'form is nil' do
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
      let(:datestamp_instance) { instance_double(PDFUtilities::DatestampPdf) }
      let(:current_file_path) { 'current-file-path' }
      let(:current_loa) { 3 }

      before do
        allow(instance).to receive(:verify).and_call_original
        allow(File).to receive_messages(rename: true, exist?: true)
        allow(File).to receive(:size).and_return(0, 1)
      end

      PersistentAttachments::VAForm::CONFIGS.keys.map(&:downcase).each do |form_number|
        context "for form #{form_number}" do
          let(:form_id) { "vba_#{form_number.gsub('-', '_')}" }
          let(:stamped_template_path) { "modules/simple_forms_api/spec/fixtures/pdfs/#{form_id}-completed.pdf" }
          let(:timestamp) { Time.current }
          let(:instance) { described_class.new(stamped_template_path:, current_loa:, timestamp:) }

          before do
            allow(instance).to receive(:verified_multistamp)
            allow(instance).to receive(:get_page_configuration)
          end

          context 'when stamped_template_path exists' do
            before do
              allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_instance)
              allow(datestamp_instance).to receive(:run).and_return(current_file_path)

              instance.stamp_pdf
            end

            it 'calls the Datestamp PDF service' do
              expect(datestamp_instance).to have_received(:run)
            end

            it 'renames the file' do
              expect(File).to have_received(:rename).with(current_file_path, stamped_template_path)
            end

            it 'verifies the file size' do
              expect(File).to have_received(:exist?).with(stamped_template_path)
              expect(File).to have_received(:size).with(stamped_template_path).twice
            end
          end

          context 'when actually stamping the pdf' do
            subject(:run) { instance.stamp_pdf }

            let(:original_pdf_path) { "modules/simple_forms_api/spec/fixtures/pdfs/#{form_id}-completed.pdf" }
            let(:tmp_dir) { Rails.root.join('tmp', 'stamped_pdfs') }
            let(:stamped_output_path) { "#{tmp_dir}/#{form_id}-stamped.pdf" }

            before do
              FileUtils.mkdir_p(tmp_dir)
              FileUtils.cp(original_pdf_path, stamped_output_path)

              allow(instance).to receive(:stamped_template_path).and_return(stamped_output_path)

              allow(PDFUtilities::DatestampPdf).to receive(:new).and_call_original
              allow_any_instance_of(PDFUtilities::DatestampPdf).to receive(:run).and_call_original
              allow(instance).to receive(:verify).and_call_original
              allow(File).to receive(:rename).and_call_original
              allow(File).to receive(:exist?).and_call_original
              allow(File).to receive(:size).and_call_original
            end

            it 'does not raise an error and deposits stamped PDFs into tmp/' do
              expect { run }.not_to raise_error
              expect(File).to exist(stamped_output_path)
            end
          end
        end
      end
    end
  end

  describe 'scanned form stamps' do
    let(:datestamp_instance) { instance_double(PDFUtilities::DatestampPdf) }
    let(:current_file_path) { 'current-file-path' }
    let(:current_loa) { 3 }
    let(:timestamp) { Time.zone.parse('2025-11-07 18:35:00 UTC') }
    let(:stamped_template_path) do
      'modules/simple_forms_api/spec/fixtures/pdfs/vba_21_0779-completed.pdf'
    end

    before do
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_instance)
      allow(datestamp_instance).to receive(:run).and_return(current_file_path)
      allow(File).to receive_messages(rename: true, exist?: true)
      allow(File).to receive(:size).and_return(0, 1)
    end

    context 'when form is a string (scanned form number)' do
      context 'for a form with stamps configured' do
        let(:form_number) { '21-0779' }
        let(:instance) do
          described_class.new(
            stamped_template_path:,
            form: form_number,
            current_loa:,
            timestamp:
          )
        end

        before do
          allow(instance).to receive(:verify).and_call_original
          allow(instance).to receive(:verified_multistamp)
          allow(instance).to receive(:get_page_configuration)
        end

        it 'checks if the form has stamps configured' do
          expect(SimpleFormsApi::ScannedFormStamps).to receive(:stamps?).with(form_number).and_call_original

          instance.stamp_pdf
        end

        it 'creates a ScannedFormStamps instance' do
          expect(SimpleFormsApi::ScannedFormStamps).to receive(:new).with(form_number).and_call_original

          instance.stamp_pdf
        end

        it 'retrieves submission_date_stamps from the config' do
          stamp_config = instance_double(SimpleFormsApi::ScannedFormStamps)
          allow(SimpleFormsApi::ScannedFormStamps).to receive(:new).and_return(stamp_config)
          allow(stamp_config).to receive(:submission_date_stamps).and_return([])

          instance.stamp_pdf

          expect(stamp_config).to have_received(:submission_date_stamps).with(timestamp)
        end

        it 'applies the stamps to the PDF' do
          allow(instance).to receive(:stamp_form)

          instance.stamp_pdf

          # Should call stamp_form for each stamp returned by submission_date_stamps
          # The actual count depends on the configuration
          expect(instance).to have_received(:stamp_form).at_least(:once)
        end

        it 'applies the authentication footer' do
          text = /Submitted via VA.gov at /

          instance.stamp_pdf

          expect(datestamp_instance).to have_received(:run).with(
            text:,
            x: anything,
            y: anything,
            text_only: false,
            size: 9,
            timestamp:
          )
        end
      end

      context 'for a form without stamps configured' do
        let(:form_number) { '21-4192' }
        let(:instance) do
          described_class.new(
            stamped_template_path:,
            form: form_number,
            current_loa:,
            timestamp:
          )
        end

        before do
          allow(instance).to receive(:verify).and_call_original
        end

        it 'checks if the form has stamps configured' do
          expect(SimpleFormsApi::ScannedFormStamps).to receive(:stamps?).with(form_number).and_return(false)

          instance.stamp_pdf
        end

        it 'does not create a ScannedFormStamps instance' do
          allow(SimpleFormsApi::ScannedFormStamps).to receive(:stamps?).and_return(false)
          expect(SimpleFormsApi::ScannedFormStamps).not_to receive(:new)

          instance.stamp_pdf
        end

        it 'does not call stamp_form' do
          allow(instance).to receive(:stamp_form)

          instance.stamp_pdf

          expect(instance).not_to have_received(:stamp_form)
        end

        it 'still applies the authentication footer' do
          text = /Submitted via VA.gov at /

          instance.stamp_pdf

          expect(datestamp_instance).to have_received(:run).with(
            text:,
            x: anything,
            y: anything,
            text_only: false,
            size: 9,
            timestamp:
          )
        end
      end

      context 'for an unknown form number' do
        let(:form_number) { '99-9999' }
        let(:instance) do
          described_class.new(
            stamped_template_path:,
            form: form_number,
            current_loa:,
            timestamp:
          )
        end

        before do
          allow(instance).to receive(:verify).and_call_original
        end

        it 'treats it as a form without stamps' do
          allow(instance).to receive(:stamp_form)

          instance.stamp_pdf

          expect(instance).not_to have_received(:stamp_form)
        end

        it 'still applies the authentication footer' do
          text = /Submitted via VA.gov at /

          instance.stamp_pdf

          expect(datestamp_instance).to have_received(:run).with(
            text:,
            x: anything,
            y: anything,
            text_only: false,
            size: 9,
            timestamp:
          )
        end
      end

      context 'when ScannedFormStamps raises an error' do
        let(:form_number) { '21-0779' }
        let(:instance) do
          described_class.new(
            stamped_template_path:,
            form: form_number,
            current_loa:,
            timestamp:
          )
        end

        before do
          allow(instance).to receive(:verify).and_call_original
          allow(SimpleFormsApi::ScannedFormStamps).to receive(:stamps?).and_return(true)
          allow(SimpleFormsApi::ScannedFormStamps).to receive(:new).and_raise(StandardError, 'Config error')
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(
            'Simple forms api - error loading scanned form stamps',
            hash_including(form_number:, error: 'Config error')
          )

          instance.stamp_pdf
        end

        it 'continues without stamps' do
          allow(instance).to receive(:stamp_form)

          instance.stamp_pdf

          expect(instance).not_to have_received(:stamp_form)
        end

        it 'still applies the authentication footer' do
          text = /Submitted via VA.gov at /

          instance.stamp_pdf

          expect(datestamp_instance).to have_received(:run).with(
            text:,
            x: anything,
            y: anything,
            text_only: false,
            size: 9,
            timestamp:
          )
        end
      end
    end

    describe '#all_form_stamps' do
      let(:timestamp) { Time.zone.parse('2025-11-07 18:35:00 UTC') }
      let(:stamped_template_path) { 'test-path' }

      context 'when form is a String' do
        it 'returns stamps from ScannedFormStamps if configured' do
          instance = described_class.new(
            stamped_template_path:,
            form: '21-0779',
            timestamp:
          )

          stamps = instance.send(:all_form_stamps)

          expect(stamps).to be_an(Array)
          expect(stamps).not_to be_empty
        end

        it 'returns empty array if not configured' do
          instance = described_class.new(
            stamped_template_path:,
            form: '21-4192',
            timestamp:
          )

          stamps = instance.send(:all_form_stamps)

          expect(stamps).to eq([])
        end
      end

      context 'when form is nil' do
        it 'returns empty array' do
          instance = described_class.new(
            stamped_template_path:,
            form: nil,
            timestamp:
          )

          stamps = instance.send(:all_form_stamps)

          expect(stamps).to eq([])
        end
      end

      context 'when form is an object' do
        it 'returns stamps from the form object' do
          form = instance_double(SimpleFormsApi::VBA2010206)
          allow(form).to receive_messages(desired_stamps: [{ text: 'test' }],
                                          submission_date_stamps: [{ text: 'date' }])

          instance = described_class.new(
            stamped_template_path:,
            form:,
            timestamp:
          )

          stamps = instance.send(:all_form_stamps)

          expect(stamps).to eq([{ text: 'test' }, { text: 'date' }])
        end
      end
    end
  end
end
