# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'
require 'common/convert_to_pdf'

RSpec.describe 'IvcChampva::V1::Forms::Uploads', type: :request do
  # forms_numbers_and_classes is a hash that maps form numbers if they have attachments
  form_numbers_and_classes = {
    '10-10D' => IvcChampva::VHA1010d,
    '10-7959C' => IvcChampva::VHA107959c,
    '10-7959F-2' => IvcChampva::VHA107959f2,
    '10-7959F-1' => IvcChampva::VHA107959f1,
    '10-7959A' => IvcChampva::VHA107959a
  }

  forms = [
    'vha_10_10d.json',
    'vha_10_7959f_1.json',
    'vha_10_7959f_2.json',
    'vha_10_7959c.json',
    'vha_10_7959a.json'
  ]

  let(:ves_request) { double('IvcChampva::VesRequest') }
  let(:ves_client) { double('IvcChampva::VesApi::Client') }

  before do
    @original_aws_config = Aws.config.dup
    Aws.config.update(stub_responses: true)
    allow(IvcChampva::VesDataFormatter).to receive(:format_for_request).and_return(ves_request)
    allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
    allow(ves_client).to receive(:submit_1010d).with(anything, anything, anything)
    allow(ves_request).to receive_messages(transaction_uuid: '78444a0b-3ac8-454d-a28d-8d63cddd0d3b',
                                           application_uuid: 'test-uuid')
    allow(ves_request).to receive(:transaction_uuid=)
    allow(ves_request).to receive(:to_json).and_return('{}')
    allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(false)
  end

  after do
    Aws.config = @original_aws_config
  end

  describe 'run this section with both values of champva_retry_logic_refactor expecting identical behavior' do
    retry_logic_refactor_values = [false, true]
    retry_logic_refactor_values.each do |champva_retry_logic_refactor_state|
      describe '#submit with flipper champva_send_to_ves enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:champva_send_to_ves, @current_user)
            .and_return(true)
          allow(Flipper).to receive(:enabled?)
            .with(:champva_retry_logic_refactor, @current_user)
            .and_return(champva_retry_logic_refactor_state)
          allow(Flipper).to receive(:enabled?)
            .with(:champva_update_datadog_tracking, @current_user)
            .and_return(false)
        end

        forms.each do |form|
          fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', form)
          data = JSON.parse(fixture_path.read)

          it 'uploads a PDF file to S3' do
            mock_form = double(first_name: 'Veteran', last_name: 'Surname', form_uuid: 'some_uuid')
            allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
              .and_return(double('Record1', created_at: 1.day.ago, id: 'some_uuid', file: double(id: 'file0')))
            allow(IvcChampvaForm).to receive(:first).and_return(mock_form)
            allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(
              double('response',
                     context: double('context', http_response: double('http_response', status_code: 200)))
            )

            post '/ivc_champva/v1/forms', params: data

            record = IvcChampvaForm.first

            expect(record.first_name).to eq('Veteran')
            expect(record.last_name).to eq('Surname')
            expect(record.form_uuid).to be_present

            expect(response).to have_http_status(:ok)
          end

          it 'returns a 500 error when supporting documents are submitted, but are missing from the database' do
            allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(true)

            # Actual supporting_docs should exist as records in the DB. This test
            # ensures that if they aren't present we won't have a silent failure
            data_with_docs = data.merge({ supporting_docs: [{ confirmation_code: 'NOT_IN_DATABASE' }] })
            post '/ivc_champva/v1/forms', params: data_with_docs

            expect(response).to have_http_status(:internal_server_error)
          end

          it 'does VES processing only for form 10-10D' do
            controller = IvcChampva::V1::UploadsController.new
            allow(controller).to receive_messages(call_handle_file_uploads: [[200], nil],
                                                  call_upload_form: [[200], nil],
                                                  get_file_paths_and_metadata: [['path'], {}],
                                                  params: ActionController::Parameters.new(data))
            allow(controller).to receive(:render)

            controller.send(:submit)

            if data['form_number'] == '10-10D'
              expect(IvcChampva::VesDataFormatter).to have_received(:format_for_request)
              # make sure submit_1010d is called with the request object from the formatter
              expect(ves_client).to have_received(:submit_1010d).with(anything, anything, ves_request)
            else
              expect(IvcChampva::VesDataFormatter).not_to have_received(:format_for_request)
              expect(ves_client).not_to have_received(:submit_1010d)
            end
          end

          it 'returns an error and does proceed when format_for_request throws an error' do
            if data['form_number'] == '10-10D'
              allow(IvcChampva::VesDataFormatter).to receive(:format_for_request)
                .and_raise(StandardError.new('oh no'))
              controller = IvcChampva::V1::UploadsController.new
              allow(controller).to receive(:call_handle_file_uploads)
              allow(controller).to receive(:params).and_return(ActionController::Parameters.new(data))
              allow(controller).to receive(:render)

              controller.send(:submit)

              expect(controller).not_to have_received(:call_handle_file_uploads)
              expect(ves_client).not_to have_received(:submit_1010d)
              expect(controller).to have_received(:render)
                .with({ json: { error_message: 'Error: oh no' }, status: :internal_server_error })
            end
          end

          it 'returns an error and does not proceed when format_for_request returns nil' do
            if data['form_number'] == '10-10D'
              allow(IvcChampva::VesDataFormatter).to receive(:format_for_request).and_return(nil)
              controller = IvcChampva::V1::UploadsController.new
              allow(controller).to receive(:call_handle_file_uploads)
              allow(controller).to receive(:params).and_return(ActionController::Parameters.new(data))
              allow(controller).to receive(:render)

              controller.send(:submit)

              expect(controller).not_to have_received(:call_handle_file_uploads)
              expect(ves_client).not_to have_received(:submit_1010d)
              expect(controller).to have_received(:render)
                .with({
                        json: { error_message: 'Error: Failed to format data for VES submission' },
                        status: :internal_server_error
                      })
            end
          end

          it 'returns an error and does not proceed when handle_file_uploads fails' do
            if data['form_number'] == '10-10D'
              controller = IvcChampva::V1::UploadsController.new
              allow(controller).to receive_messages(call_upload_form: [[400], 'oh no'],
                                                    get_file_paths_and_metadata: [['path'], {}],
                                                    params: ActionController::Parameters.new(data))
              allow(controller).to receive(:render)

              controller.send(:submit)

              expect(ves_client).not_to have_received(:submit_1010d)
              expect(controller).to have_received(:render)
                .with({ json: { error_message: 'oh no' }, status: 400 })
            end
          end

          it 'returns ok when submitting to VES results in an error' do
            if data['form_number'] == '10-10D'
              # These must be mocked in order for submit to be able to complete successfully: find_by, put_object
              allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
                .and_return(double('Record1', created_at: 1.day.ago,
                                              id: 'some_uuid', file: double(id: 'file0')))
              allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(
                double('response',
                       context: double('context', http_response: double('http_response', status_code: 200)))
              )
              # Mock VES returning an error
              allow(ves_client).to receive(:submit_1010d).and_raise(IvcChampva::VesApi::VesApiError.new('oh no'))

              post '/ivc_champva/v1/forms', params: data

              expect(response).to have_http_status(:ok)
            end
          end

          context 'with retry feature enabled' do
            before do
              allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit, @current_user).and_return(false)
            end
          end

          it 'retries VES submission if it fails' do
            with_settings(Settings, vsp_environment: 'staging') do
              if data['form_number'] == '10-10D'
                allow(ves_request).to receive(:transaction_uuid).and_return('fake-id')

                controller = IvcChampva::V1::UploadsController.new

                allow(ves_client).to receive(:submit_1010d)
                  .with(anything, anything, anything)
                  .and_raise(IvcChampva::VesApi::VesApiError.new('oh no'))

                allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)

                controller.send(:submit_ves_request, ves_request, {})

                expect(ves_client).to have_received(:submit_1010d).twice
              end
            end
          end
        end
      end
    end
  end

  describe '#submit with champva_update_datadog_tracking enabled' do
    let(:form_with_track_submission) { 'vha_10_10d.json' }

    before do
      # Mirror the setup from the passing tests, but enable champva_update_datadog_tracking
      allow(Flipper).to receive(:enabled?)
        .with(:champva_send_to_ves, @current_user)
        .and_return(true)
      allow(Flipper).to receive(:enabled?)
        .with(:champva_retry_logic_refactor, @current_user)
        .and_return(false)
      allow(Flipper).to receive(:enabled?)
        .with(:champva_update_datadog_tracking, @current_user)
        .and_return(true)
    end

    it 'calls track_submission on form models that respond to it' do
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json',
                                     form_with_track_submission)
      data = JSON.parse(fixture_path.read)

      mock_form = double(first_name: 'Veteran', last_name: 'Surname', form_uuid: 'some_uuid')
      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
        .and_return(double('Record1', created_at: 1.day.ago, id: 'some_uuid', file: double(id: 'file0')))
      allow(IvcChampvaForm).to receive(:first).and_return(mock_form)
      allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(
        double('response',
               context: double('context', http_response: double('http_response', status_code: 200)))
      )

      # Allow all StatsD calls, but specifically check for the .submission call
      allow(StatsD).to receive(:increment).and_call_original

      post '/ivc_champva/v1/forms', params: data

      expect(response).to have_http_status(:ok)
      # Verify track_submission was called by checking the StatsD increment
      expect(StatsD).to have_received(:increment).with(
        'api.ivc_champva_form.10_10d.submission',
        hash_including(:tags)
      )
    end

    it 'does not call track_submission on form models that do not respond to it' do
      # 10-7959F-1 does not have track_submission implemented (method_missing returns a hash, not StatsD calls)
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_7959f_1.json')
      data = JSON.parse(fixture_path.read)

      mock_form = double(first_name: 'Veteran', last_name: 'Surname', form_uuid: 'some_uuid')
      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
        .and_return(double('Record1', created_at: 1.day.ago, id: 'some_uuid', file: double(id: 'file0')))
      allow(IvcChampvaForm).to receive(:first).and_return(mock_form)
      allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(
        double('response',
               context: double('context', http_response: double('http_response', status_code: 200)))
      )

      # Allow all StatsD calls so we can verify later
      allow(StatsD).to receive(:increment).and_call_original

      post '/ivc_champva/v1/forms', params: data

      expect(response).to have_http_status(:ok)
      # Verify track_submission was NOT called (7959F-1 doesn't have it implemented)
      expect(StatsD).not_to have_received(:increment).with(
        'api.ivc_champva_form.10_7959f_1.submission',
        anything
      )
    end
  end

  describe '#submit with flipper champva_send_to_ves disabled' do
    before do
      allow(Flipper).to receive(:enabled?)
        .with(:champva_send_to_ves, @current_user)
        .and_return(false)
    end

    forms.each do |form|
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', form)
      data = JSON.parse(fixture_path.read)

      it 'does not format data for VES' do
        post '/ivc_champva/v1/forms', params: data
        expect(IvcChampva::VesDataFormatter).not_to have_received(:format_for_request)
      end

      it 'does not submit to VES' do
        post '/ivc_champva/v1/forms', params: data
        expect(ves_client).not_to have_received(:submit_1010d)
      end
    end
  end

  # Shared examples for testing missing form_number parameter
  shared_examples 'returns HTTP 400 for missing form_number' do |endpoint_path|
    it 'returns HTTP 400 when form_number parameter is missing' do
      post endpoint_path, params: {}

      expect(response).to have_http_status(:bad_request)
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to be_present
      expect(json_response['errors'].first['title']).to include('Missing parameter')
    end
  end

  describe '#submit error handling' do
    include_examples 'returns HTTP 400 for missing form_number', '/ivc_champva/v1/forms'
  end

  # Copied this test from the #submit endpoint tests above and adjusted to use
  # the new endpoint. We'll need more tests in future, but wanted to have at
  # least one verifying it wasn't throwing rampant errors
  describe '#submit_champva_app_merged' do
    fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json',
                                   'vha_10_10d_extended.json')
    data = JSON.parse(fixture_path.read)

    it 'uploads a PDF file to S3' do
      mock_form = double(first_name: 'Veteran', last_name: 'Surname', form_uuid: 'some_uuid')
      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
        .and_return(double('Record1', created_at: 1.day.ago, id: 'some_uuid', file: double(id: 'file0')))
      allow(IvcChampvaForm).to receive(:first).and_return(mock_form)
      allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(
        double('response',
               context: double('context', http_response: double('http_response', status_code: 200)))
      )

      post '/ivc_champva/v1/forms/10-10d-ext', params: data

      record = IvcChampvaForm.first

      expect(record.first_name).to eq('Veteran')
      expect(record.last_name).to eq('Surname')
      expect(record.form_uuid).to be_present

      expect(response).to have_http_status(:ok)
    end

    include_examples 'returns HTTP 400 for missing form_number', '/ivc_champva/v1/forms/10-10d-ext'

    # Also taken from the main #submit endpoint tests as they function the same at this level
    it 'returns a 500 error when supporting documents are submitted, but are missing from the database' do
      allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(true)

      # Actual supporting_docs should exist as records in the DB. This test
      # ensures that if they aren't present we won't have a silent failure
      data_with_docs = data.merge({ supporting_docs: [{ confirmation_code: 'NOT_IN_DATABASE' }] })
      post '/ivc_champva/v1/forms/10-10d-ext', params: data_with_docs

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'tracks the delegate form' do
      # Create a mock form instance that will be returned by generate_ohi_form
      mock_form = instance_double(IvcChampva::VHA107959cRev2025)
      allow(mock_form).to receive(:track_delegate_form)
      allow(mock_form).to receive(:respond_to?).with(:track_delegate_form).and_return(true)

      # Stub the controller methods to bypass the complex PDF generation flow
      allow_any_instance_of(IvcChampva::V1::UploadsController).to receive(:generate_ohi_form)
                                                              .and_return([mock_form])
      allow_any_instance_of(IvcChampva::V1::UploadsController).to receive(:fill_ohi_and_return_path)
                                                              .and_return('/tmp/test.pdf')
      allow_any_instance_of(IvcChampva::V1::UploadsController).to receive(:create_custom_attachment).and_return({})
      allow_any_instance_of(IvcChampva::V1::UploadsController).to receive(:add_supporting_doc)
      allow_any_instance_of(IvcChampva::V1::UploadsController).to receive(:submit).and_return(nil)

      post '/ivc_champva/v1/forms/10-10d-ext', params: data

      # Verify the method was called with the correct parent form ID
      expect(mock_form).to have_received(:track_delegate_form).with('vha_10_10d')
    end
  end

  describe 'stored ves data is encrypted' do
    it 'ves_request_data is encrypted' do
      # This is the only part of the test we actually need
      expect(IvcChampvaForm.new).to encrypt_attr(:ves_request_data)
    end
  end

  describe '#submit_supporting_documents' do
    let(:file) { fixture_file_upload('doctors-note.gif') }

    before do
      allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit, @current_user).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:champva_convert_to_pdf_on_upload, anything).and_return(false)
    end

    context 'successful transaction' do
      it 'renders the attachment as json' do
        clamscan = double(safe?: true)
        allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

        data_sets = [
          { form_id: '10-10D', file: }
        ]

        data_sets.each do |data|
          expect do
            post '/ivc_champva/v1/forms/submit_supporting_documents', params: data
          end.to change(PersistentAttachment, :count).by(1)

          expect(response).to have_http_status(:ok)
          resp = JSON.parse(response.body)
          expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])
          expect(PersistentAttachment.last).to be_a(PersistentAttachments::MilitaryRecords)
        end
      end
    end

    context 'LLM response integration' do
      let(:clamscan) { double(safe?: true) }

      before do
        allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      end

      context 'when LLM conditions are met' do
        before do
          # Mock Flipper for both @current_user (which might be set) and nil (which is typical in these tests)
          allow(Flipper).to receive(:enabled?).with(:champva_claims_llm_validation, @current_user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:champva_claims_llm_validation, nil).and_return(true)
        end

        it 'includes llm_response in the JSON for 10-7959A form' do
          # Set up AWS mocking for individual test runs (prevents real AWS calls)
          original_aws_config = Aws.config.dup
          Aws.config.update(stub_responses: true)

          # Ensure virus scan mock is set up for individual test runs
          clamscan = double(safe?: true)
          allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

          # Mock background job launching to prevent OCR job from hanging on file I/O
          allow_any_instance_of(IvcChampva::V1::UploadsController)
            .to receive(:launch_background_job)

          # Create a mock response that matches the structure returned by MockClient
          # rubocop:disable Layout/LineLength
          mock_response = {
            body: {
              answer: '```json
                      {
                        "doc_type": "EOB",
                        "doc_type_matches": true,
                        "valid": false,
                        "confidence": 0.9,
                        "missing_fields": [
                          "Provider NPI (10-digit)",
                          "Services Paid For (CPT/HCPCS code or description)"
                        ],
                        "present_fields": {
                          "Date of Service": "01/29/13",
                          "Provider Name": "Smith, Robert",
                          "Amount Paid by Insurance": "0.00"
                        },
                        "notes": "The document is classified as an EOB. Missing required fields for Provider NPI and Services Paid For."
                      }
                      ```'
            }.to_json
          }
          # rubocop:enable Layout/LineLength

          # Parse the response the same way call_llm_service does
          parsed_response = JSON.parse(mock_response[:body])
          answer_content = parsed_response['answer']
          cleaned_content = answer_content.strip.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
          mock_client_response = JSON.parse(cleaned_content)

          allow_any_instance_of(IvcChampva::V1::UploadsController)
            .to receive(:call_llm_service)
            .and_return(mock_client_response)

          data = { form_id: '10-7959A', file:, attachment_id: 'test_document' }

          post '/ivc_champva/v1/forms/submit_supporting_documents', params: data

          expect(response).to have_http_status(:ok)
          resp = JSON.parse(response.body)

          # Should have the standard attachment data
          expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])

          # Should have LLM response data that matches MockClient structure
          expect(resp).to have_key('llm_response')
          expect(resp['llm_response']).to eq(mock_client_response)
        ensure
          # Restore original AWS config
          Aws.config = original_aws_config if defined?(original_aws_config)
        end

        it 'does not include llm_response for non-7959A forms even when flipper is enabled' do
          data = { form_id: '10-10D', file:, attachment_id: 'test_document' }

          post '/ivc_champva/v1/forms/submit_supporting_documents', params: data

          expect(response).to have_http_status(:ok)
          resp = JSON.parse(response.body)

          # Should have the standard attachment data
          expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])

          # Should NOT have LLM response data
          expect(resp).not_to have_key('llm_response')
        end

        it 'successfully processes LLM validation end-to-end' do
          # Mock background job launching to prevent OCR job from hanging
          allow_any_instance_of(IvcChampva::V1::UploadsController)
            .to receive(:launch_background_job)

          # Disable PDF conversion on upload for this test (not testing that feature here)
          allow(Flipper).to receive(:enabled?).with(:champva_convert_to_pdf_on_upload, anything).and_return(false)

          # Mock Common::ConvertToPdf to avoid ImageMagick issues in test environment
          dummy_pdf_path = Rails.root.join('tmp', 'test_converted.pdf').to_s
          allow_any_instance_of(Common::ConvertToPdf).to receive(:run).and_return(dummy_pdf_path)

          # Mock file existence check for LlmService.validate_file_exists
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(dummy_pdf_path).and_return(true)

          data = { form_id: '10-7959A', file:, attachment_id: 'test_document' }

          post '/ivc_champva/v1/forms/submit_supporting_documents', params: data

          expect(response).to have_http_status(:ok)
          resp = JSON.parse(response.body)

          # Should have the standard attachment data
          expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])

          # Should have LLM response data from MockClient
          expect(resp).to have_key('llm_response')
          expect(resp['llm_response']).to include(
            'doc_type' => 'EOB',
            'doc_type_matches' => true,
            'valid' => false,
            'confidence' => 0.9
          )
        end
      end

      context 'when LLM conditions are not met' do
        before do
          allow(Flipper).to receive(:enabled?).with(:champva_claims_llm_validation, @current_user).and_return(false)
        end

        it 'does not include llm_response when flipper is disabled' do
          data = { form_id: '10-7959A', file:, attachment_id: 'test_document' }

          post '/ivc_champva/v1/forms/submit_supporting_documents', params: data

          expect(response).to have_http_status(:ok)
          resp = JSON.parse(response.body)

          # Should have the standard attachment data
          expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])

          # Should NOT have LLM response data
          expect(resp).not_to have_key('llm_response')
        end
      end
    end

    context 'with an invalid form_id' do
      it 'returns an error' do
        post '/ivc_champva/v1/forms/submit_supporting_documents', params: { form_id: 'invalid', file: }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with an invalid file format' do
      it 'raises a validation error' do
        allow_any_instance_of(PersistentAttachments::MilitaryRecords).to receive(:valid?).and_return(false)
        post '/ivc_champva/v1/forms/submit_supporting_documents', params: { form_id: '10-10D', file: }
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe '#unlock_file' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:file) { fixture_file_upload('locked_pdf_password_is_test.pdf') }

    before do
      allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit, @current_user).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:champva_use_hexapdf_to_unlock_pdfs, @current_user).and_return(true)
    end

    context 'with locked PDF and no provided password' do
      let(:locked_file) { fixture_file_upload('locked_pdf_password_is_test.pdf', 'application/pdf') }

      it 'rejects locked PDFs if no password is provided' do
        post '/ivc_champva/v1/forms/submit_supporting_documents', params: { form_id: '10-10D', file: locked_file }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          response.parsed_body['errors'].first['title']
        ).to eq("File #{I18n.t('errors.messages.uploads.pdf.invalid')}")
      end

      it 'accepts locked PDFs with the correct password' do
        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: locked_file, password: 'test' }
        expect(response).to have_http_status(:ok)
      end

      it 'rejects locked PDFs with the incorrect password' do
        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: locked_file, password: 'bad' }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'handles non-PDF files' do
      non_pdf_file = fixture_file_upload('doctors-note.gif')
      expect(controller.send(:unlock_file, non_pdf_file, nil)).to eq(non_pdf_file)
    end

    it 'handles PDFs with no password' do
      expect(controller.send(:unlock_file, file, nil)).to eq(file)
    end
  end

  describe '#unlock_file via pdftk' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:file) { fixture_file_upload('locked_pdf_password_is_test.pdf') }

    before do
      allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit, @current_user).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:champva_use_hexapdf_to_unlock_pdfs, @current_user).and_return(false)
    end

    context 'with locked PDF and no provided password' do
      let(:locked_file) { fixture_file_upload('locked_pdf_password_is_test.pdf', 'application/pdf') }

      it 'rejects locked PDFs if no password is provided' do
        post '/ivc_champva/v1/forms/submit_supporting_documents', params: { form_id: '10-10D', file: locked_file }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          response.parsed_body['errors'].first['title']
        ).to eq("File #{I18n.t('errors.messages.uploads.pdf.invalid')}")
      end

      it 'accepts locked PDFs with the correct password' do
        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: locked_file, password: 'test' }
        expect(response).to have_http_status(:ok)
      end

      it 'rejects locked PDFs with the incorrect password' do
        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: locked_file, password: 'bad' }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'handles non-PDF files' do
      non_pdf_file = fixture_file_upload('doctors-note.gif')
      expect(controller.send(:unlock_file, non_pdf_file, nil)).to eq(non_pdf_file)
    end

    it 'handles PDFs with no password' do
      expect(controller.send(:unlock_file, file, nil)).to eq(file)
    end
  end

  describe '#convert_to_pdf' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:clamscan) { double(safe?: true) }
    let(:source_pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'attachment.pdf').to_s }

    before do
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      # Allow all Flipper calls through by default, then override specific ones in contexts
      allow(Flipper).to receive(:enabled?).and_return(false)
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_convert_to_pdf_on_upload, anything).and_return(true)
      end

      it 'converts image files to PDF at upload time' do
        image_file = fixture_file_upload('doctors-note.png', 'image/png')

        # Create a temp file that mimics what ConvertToPdf would return
        temp_pdf = Tempfile.new(['converted', '.pdf'])
        FileUtils.cp(source_pdf_path, temp_pdf.path)

        allow_any_instance_of(Common::ConvertToPdf).to receive(:run).and_return(temp_pdf.path)

        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: image_file }

        expect(response).to have_http_status(:ok)

        attachment = PersistentAttachment.last
        expect(attachment.file.content_type).to eq('application/pdf')
        expect(attachment.original_filename).to end_with('.pdf')
      ensure
        temp_pdf&.close
        temp_pdf&.unlink
      end

      it 'preserves the original filename with pdf extension' do
        image_file = fixture_file_upload('doctors-note.png', 'image/png')

        # Create a temp file that mimics what ConvertToPdf would return
        temp_pdf = Tempfile.new(['converted', '.pdf'])
        FileUtils.cp(source_pdf_path, temp_pdf.path)

        allow_any_instance_of(Common::ConvertToPdf).to receive(:run).and_return(temp_pdf.path)

        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: image_file }

        expect(response).to have_http_status(:ok)

        attachment = PersistentAttachment.last
        expect(attachment.original_filename).to eq('doctors-note.pdf')
      ensure
        temp_pdf&.close
        temp_pdf&.unlink
      end

      it 'skips conversion for files that are already PDFs' do
        pdf_file = fixture_file_upload('attachment.pdf', 'application/pdf')

        # pre_convert_to_pdf! should return early when content_type is application/pdf
        # so ConvertToPdf should never be instantiated
        expect(Common::ConvertToPdf).not_to receive(:new)

        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: pdf_file }

        expect(response).to have_http_status(:ok)

        attachment = PersistentAttachment.last
        expect(attachment.file.content_type).to eq('application/pdf')
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_convert_to_pdf_on_upload, anything).and_return(false)
      end

      it 'does not convert image files to PDF at upload time' do
        image_file = fixture_file_upload('doctors-note.png', 'image/png')

        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: image_file }

        expect(response).to have_http_status(:ok)

        attachment = PersistentAttachment.last
        expect(attachment.file.content_type).to eq('image/png')
        expect(attachment.original_filename).to eq('doctors-note.png')
      end
    end

    context 'when conversion fails' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_convert_to_pdf_on_upload, anything).and_return(true)
        allow_any_instance_of(Common::ConvertToPdf).to receive(:run).and_raise(StandardError, 'Conversion failed')
      end

      it 'raises an error and returns internal server error' do
        image_file = fixture_file_upload('doctors-note.png', 'image/png')

        post '/ivc_champva/v1/forms/submit_supporting_documents',
             params: { form_id: '10-10D', file: image_file }

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe '#get_form_id' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    it 'returns the correct form ID for a valid form number' do
      allow(controller).to receive(:params).and_return({ form_number: '10-10D' })
      form_id = controller.send(:get_form_id)

      expect(form_id).to eq('vha_10_10d')
    end

    it 'raises an error for a missing form number' do
      allow(controller).to receive(:params).and_return({})
      expect { controller.send(:get_form_id) }.to raise_error(Common::Exceptions::ParameterMissing)
    end
  end

  describe '#get_attachment_ids_and_form' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:mock_user) { double('User', loa: { current: 3 }) }

    before do
      allow(Flipper).to receive(:enabled?).with(:champva_form_versioning, anything).and_return(false)
      allow(controller).to receive_messages(
        params: { form_number: '10-10D' },
        current_user: mock_user
      )
    end

    context 'with form 10-10D' do
      let(:parsed_form_data) do
        {
          'form_number' => '10-10D',
          'applicants' => [
            { 'first_name' => 'John', 'last_name' => 'Doe' },
            { 'first_name' => 'Jane', 'last_name' => 'Doe' }
          ],
          'supporting_docs' => [
            { 'confirmation_code' => 'code1', 'attachment_id' => 'doc1' },
            { 'confirmation_code' => 'code2', 'attachment_id' => 'doc2' }
          ]
        }
      end

      it 'returns attachment ids and form with correct data' do
        # Mock the supporting documents in the database
        record1 = double('Record1', created_at: 1.day.ago, file: double(id: 'file1'))
        record2 = double('Record2', created_at: Time.zone.now, file: double(id: 'file2'))
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by).with(guid: 'code1').and_return(record1)
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by).with(guid: 'code2').and_return(record2)

        # Create actual form instance
        form_instance = IvcChampva::VHA1010d.new(parsed_form_data)
        allow(IvcChampva::VHA1010d).to receive(:new).with(parsed_form_data).and_return(form_instance)
        allow(form_instance).to receive(:track_user_identity)
        allow(form_instance).to receive(:track_current_user_loa)
        allow(form_instance).to receive(:track_email_usage)

        attachment_ids, form = controller.send(:get_attachment_ids_and_form, parsed_form_data)

        # Verify attachment IDs are correct and in order
        expect(attachment_ids).to eq(%w[vha_10_10d doc1 doc2])

        # Verify form is of correct type and contains the data
        expect(form).to be_a(IvcChampva::VHA1010d)
        expect(form.instance_variable_get(:@data)).to eq(parsed_form_data)
      end
    end

    context 'with form without applicants array' do
      let(:parsed_form_data) do
        {
          'form_number' => '10-10D',
          'supporting_docs' => [
            { 'confirmation_code' => 'code1', 'attachment_id' => 'doc1' }
          ]
        }
      end

      it 'returns at least one form ID and supporting docs' do
        record1 = double('Record1', created_at: Time.zone.now, file: double(id: 'file1'))
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by).with(guid: 'code1').and_return(record1)

        allow_any_instance_of(IvcChampva::VHA1010d).to receive(:track_user_identity)
        allow_any_instance_of(IvcChampva::VHA1010d).to receive(:track_current_user_loa)
        allow_any_instance_of(IvcChampva::VHA1010d).to receive(:track_email_usage)

        attachment_ids, form = controller.send(:get_attachment_ids_and_form, parsed_form_data)

        expect(attachment_ids).to eq(%w[vha_10_10d doc1])
        expect(form).to be_a(IvcChampva::VHA1010d)
      end
    end

    context 'with form having no supporting docs' do
      let(:parsed_form_data) do
        {
          'form_number' => '10-10D',
          'applicants' => [
            { 'first_name' => 'John', 'last_name' => 'Doe' }
          ]
        }
      end

      it 'returns only form IDs' do
        allow_any_instance_of(IvcChampva::VHA1010d).to receive(:track_user_identity)
        allow_any_instance_of(IvcChampva::VHA1010d).to receive(:track_current_user_loa)
        allow_any_instance_of(IvcChampva::VHA1010d).to receive(:track_email_usage)

        attachment_ids, form = controller.send(:get_attachment_ids_and_form, parsed_form_data)

        expect(attachment_ids).to eq(['vha_10_10d'])
        expect(form).to be_a(IvcChampva::VHA1010d)
      end
    end

    context 'with form 10-7959A resubmissions' do
      before do
        allow(controller).to receive_messages(
          params: { form_number: '10-7959A' },
          current_user: mock_user
        )
        # Enable the feature flag for resubmission attachment ID logic
        allow(Flipper).to receive(:enabled?).with(:champva_resubmission_attachment_ids).and_return(true)
      end

      context 'when PDI number is selected' do
        let(:parsed_form_data) do
          {
            'form_number' => '10-7959A',
            'claim_status' => 'resubmission',
            'pdi_or_claim_number' => 'PDI number',
            'identifying_number' => 'PDI123456',
            'claims' => [
              { 'provider_name' => 'Test Provider' }
            ],
            'supporting_docs' => [
              { 'confirmation_code' => 'code1', 'attachment_id' => 'Medical Records' },
              { 'confirmation_code' => 'code2', 'attachment_id' => 'EOB' }
            ]
          }
        end

        it 'labels all documents including main claim sheet as CVA Bene Response' do
          # Mock tracking methods
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_user_identity)
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_current_user_loa)
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_email_usage)

          # Ensure DTA flag is off so no extra stamped doc is added
          allow(Flipper).to receive(:enabled?).with(:champva_claims_duty_to_assist).and_return(false)

          attachment_ids, form = controller.send(:get_attachment_ids_and_form, parsed_form_data)

          # Verify: all documents (1 main form + 2 supporting docs) get "CVA Bene Response"
          expect(attachment_ids).to eq(['CVA Bene Response', 'CVA Bene Response', 'CVA Bene Response'])
          expect(form).to be_a(IvcChampva::VHA107959a)
        end
      end

      context 'when Claim control number is selected' do
        let(:parsed_form_data) do
          {
            'form_number' => '10-7959A',
            'claim_status' => 'resubmission',
            'pdi_or_claim_number' => 'Control number',
            'identifying_number' => 'CLAIM789',
            'claims' => [
              { 'provider_name' => 'Test Provider' }
            ],
            'supporting_docs' => [
              { 'confirmation_code' => 'code1', 'attachment_id' => 'Medical Records' },
              { 'confirmation_code' => 'code2', 'attachment_id' => 'EOB' }
            ]
          }
        end

        it 'sets main claim sheet to CVA Reopen and preserves supporting doc types' do
          # Mock the supporting documents in the database
          record1 = double('Record1', created_at: 1.day.ago, file: double(id: 'file1'))
          record2 = double('Record2', created_at: Time.zone.now, file: double(id: 'file2'))
          allow(PersistentAttachments::MilitaryRecords).to receive(:find_by).with(guid: 'code1').and_return(record1)
          allow(PersistentAttachments::MilitaryRecords).to receive(:find_by).with(guid: 'code2').and_return(record2)

          # Mock tracking methods but let stamp_metadata work naturally
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_user_identity)
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_current_user_loa)
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_email_usage)

          # Ensure DTA flag is off so no extra stamped doc is added
          allow(Flipper).to receive(:enabled?).with(:champva_claims_duty_to_assist).and_return(false)

          attachment_ids, form = controller.send(:get_attachment_ids_and_form, parsed_form_data)

          # Verify: main claim sheet gets "CVA Reopen", supporting docs retain their types
          expect(attachment_ids).to eq(['CVA Reopen', 'Medical Records', 'EOB'])
          expect(form).to be_a(IvcChampva::VHA107959a)
        end
      end

      context 'when feature flag is disabled' do
        let(:parsed_form_data) do
          {
            'form_number' => '10-7959A',
            'claim_status' => 'resubmission',
            'pdi_or_claim_number' => 'Control number',
            'identifying_number' => 'CLAIM789',
            'claims' => [
              { 'provider_name' => 'Test Provider' }
            ],
            'supporting_docs' => [
              { 'confirmation_code' => 'code1', 'attachment_id' => 'Medical Records' }
            ]
          }
        end

        before do
          # Disable the feature flag
          allow(Flipper).to receive(:enabled?).with(:champva_resubmission_attachment_ids).and_return(false)
        end

        it 'uses default behavior when feature flag is disabled' do
          # Mock the supporting documents in the database
          record1 = double('Record1', created_at: 1.day.ago, file: double(id: 'file1'))
          allow(PersistentAttachments::MilitaryRecords).to receive(:find_by).with(guid: 'code1').and_return(record1)

          # Mock tracking methods
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_user_identity)
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_current_user_loa)
          allow_any_instance_of(IvcChampva::VHA107959a).to receive(:track_email_usage)

          # Ensure DTA flag is off so no extra stamped doc is added
          allow(Flipper).to receive(:enabled?).with(:champva_claims_duty_to_assist).and_return(false)

          attachment_ids, form = controller.send(:get_attachment_ids_and_form, parsed_form_data)

          # Verify: when feature flag is disabled, uses default behavior (no special resubmission logic)
          expect(attachment_ids).to eq(['vha_10_7959a', 'Medical Records'])
          expect(form).to be_a(IvcChampva::VHA107959a)
        end
      end

      context 'metadata generation for resubmissions' do
        context 'when PDI number is selected' do
          let(:pdi_form_data) do
            {
              'form_number' => '10-7959A',
              'claim_status' => 'resubmission',
              'pdi_or_claim_number' => 'PDI number',
              'identifying_number' => 'PDI123456',
              'applicant_name' => { 'first' => 'Test', 'last' => 'User' },
              'applicant_address' => { 'postal_code' => '12345' },
              'applicant_member_number' => '123456789',
              'primary_contact_info' => { 'email' => 'test@example.com' }
            }
          end

          it 'includes pdi_number in metadata and excludes claim_number' do
            form = IvcChampva::VHA107959a.new(pdi_form_data)
            metadata = form.metadata

            expect(metadata['pdi_number']).to eq('PDI123456')
            expect(metadata['claim_number']).to be_nil
            expect(metadata['pdi_or_claim_number']).to eq('PDI number')
            expect(metadata['claim_status']).to eq('resubmission')
          end
        end

        context 'when Control number is selected' do
          let(:claim_form_data) do
            {
              'form_number' => '10-7959A',
              'claim_status' => 'resubmission',
              'pdi_or_claim_number' => 'Control number',
              'identifying_number' => 'CLAIM789',
              'applicant_name' => { 'first' => 'Test', 'last' => 'User' },
              'applicant_address' => { 'postal_code' => '12345' },
              'applicant_member_number' => '123456789',
              'primary_contact_info' => { 'email' => 'test@example.com' }
            }
          end

          it 'includes claim_number in metadata and excludes pdi_number' do
            form = IvcChampva::VHA107959a.new(claim_form_data)
            metadata = form.metadata

            expect(metadata['claim_number']).to eq('CLAIM789')
            expect(metadata['pdi_number']).to be_nil
            expect(metadata['pdi_or_claim_number']).to eq('Control number')
            expect(metadata['claim_status']).to eq('resubmission')
          end
        end
      end
    end
  end

  describe '#build_pdi_resubmission_attachment_ids' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    it 'labels all documents as CVA Bene Response for PDI resubmissions' do
      parsed_form_data = {
        'supporting_docs' => [
          { 'confirmation_code' => 'code1', 'attachment_id' => 'Medical Records' },
          { 'confirmation_code' => 'code2', 'attachment_id' => 'EOB' }
        ]
      }
      applicant_rounded_number = 1

      result = controller.send(:build_pdi_resubmission_attachment_ids, 'vha_10_7959a', parsed_form_data,
                               applicant_rounded_number)

      # 1 main form + 2 supporting docs = 3 total, all "CVA Bene Response"
      expect(result).to eq(['CVA Bene Response', 'CVA Bene Response', 'CVA Bene Response'])
    end

    it 'handles submissions with no supporting docs' do
      parsed_form_data = { 'supporting_docs' => nil }
      applicant_rounded_number = 1

      result = controller.send(:build_pdi_resubmission_attachment_ids, 'vha_10_7959a', parsed_form_data,
                               applicant_rounded_number)

      # Just 1 main form
      expect(result).to eq(['CVA Bene Response'])
    end

    it 'handles multiple main form pages' do
      parsed_form_data = {
        'supporting_docs' => [
          { 'confirmation_code' => 'code1', 'attachment_id' => 'Medical Records' }
        ]
      }
      applicant_rounded_number = 2

      result = controller.send(:build_pdi_resubmission_attachment_ids, 'vha_10_7959a', parsed_form_data,
                               applicant_rounded_number)

      # 2 main form pages + 1 supporting doc = 3 total
      expect(result).to eq(['CVA Bene Response', 'CVA Bene Response', 'CVA Bene Response'])
    end
  end

  describe '7959A PDI resubmission end-to-end S3 upload' do
    let(:base_fixture) do
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_7959a.json')
      JSON.parse(fixture_path.read)
    end
    let(:pdi_resubmission_data) do
      base_fixture.merge(
        'form_number' => '10-7959A',
        'claim_status' => 'resubmission',
        'pdi_or_claim_number' => 'PDI number',
        'identifying_number' => 'PDI123456'
      )
    end

    before do
      allow(Flipper).to receive(:enabled?).with(:champva_resubmission_attachment_ids).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:champva_claims_duty_to_assist).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:champva_send_to_ves, anything).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:champva_retry_logic_refactor, anything).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:champva_log_all_s3_uploads, anything).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit, anything).and_return(false)

      # Mock supporting document records (uses confirmation_codes from fixture)
      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
        .and_return(double('Record', created_at: 1.day.ago, id: 'some_uuid', file: double(id: 'file0')))

      # Mock IvcChampvaForm
      mock_form = double(first_name: 'Veteran', last_name: 'Surname', form_uuid: 'some_uuid')
      allow(IvcChampvaForm).to receive(:first).and_return(mock_form)
    end

    it 'uploads documents to S3 with all documents labeled CVA Bene Response' do
      s3_uploads = []

      # Capture all S3 put_object calls to verify attachment_ids
      allow_any_instance_of(Aws::S3::Client).to receive(:put_object) do |_client, params|
        s3_uploads << params[:metadata]
        double('response', context: double('context', http_response: double('http_response', status_code: 200)))
      end

      post '/ivc_champva/v1/forms', params: pdi_resubmission_data

      expect(response).to have_http_status(:ok)

      # Filter out any uploads without attachment_id (like metadata JSON)
      doc_uploads = s3_uploads.select { |m| m&.key?('attachment_id') }

      # All document uploads should have "CVA Bene Response" attachment_id
      expect(doc_uploads).not_to be_empty
      doc_uploads.each do |upload|
        expect(upload['attachment_id']).to eq('CVA Bene Response')
      end
    end
  end

  describe '#supporting_document_ids' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:parsed_form_data) do
      {
        'form_number' => '10-10D',
        'supporting_docs' => [
          { 'confirmation_code' => 'code1', 'attachment_id' => 'doc1' },
          { 'confirmation_code' => 'code2', 'attachment_id' => 'doc2' },
          { 'confirmation_code' => 'code3', 'attachment_id' => 'doc3' }
        ]
      }
    end

    context 'with valid supporting documents' do
      before do
        # Set up records in the database with specific creation times for testing order
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .with(guid: 'code1')
          .and_return(double('Record1', created_at: 2.days.ago, file: double(id: 'file1')))
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .with(guid: 'code2')
          .and_return(double('Record2', created_at: 1.day.ago, file: double(id: 'file2')))
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .with(guid: 'code3')
          .and_return(double('Record3', created_at: Time.zone.now, file: double(id: 'file3')))
      end

      it 'orders supporting document ids by date created' do
        result = controller.send(:supporting_document_ids, parsed_form_data)
        # Should be ordered from oldest to newest based on created_at
        expect(result).to eq(%w[doc1 doc2 doc3])
      end

      it 'returns empty array when no supporting docs exist' do
        form_data_without_docs = { 'form_number' => '10-10D' }
        result = controller.send(:supporting_document_ids, form_data_without_docs)
        expect(result).to eq([])
      end

      it 'handles claim_ids for form 10-7959a' do
        form_data_with_claim_ids = {
          'form_number' => '10-7959A',
          'supporting_docs' => [
            { 'claim_id' => 'claim1', 'confirmation_code' => 'code1' },
            { 'claim_id' => 'claim2', 'confirmation_code' => 'code2' }
          ]
        }

        # Mock records with created_at and file.id so we can test the fallback behavior
        record1 = double('Record1', created_at: 2.days.ago, file: double(id: 'file1'))
        record2 = double('Record2', created_at: 1.day.ago, file: double(id: 'file2'))

        # Return nil for these specific codes to trigger the claim_id fallback
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .with(guid: 'code1')
          .and_return(record1)
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .with(guid: 'code2')
          .and_return(record2)

        result = controller.send(:supporting_document_ids, form_data_with_claim_ids)
        expect(result).to eq(%w[claim1 claim2])
      end
    end

    context 'with invalid supporting documents' do
      it 'raises an error when supporting doc is not found in database' do
        invalid_form_data = {
          'form_number' => '10-10D',
          'supporting_docs' => [
            { 'confirmation_code' => 'invalid_code', 'attachment_id' => 'doc1' }
          ]
        }
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .with(guid: 'invalid_code')
          .and_return(nil)

        expect { controller.send(:supporting_document_ids, invalid_form_data) }
          .to raise_error(NoMethodError)
      end
    end
  end

  describe '#get_file_paths_and_metadata' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    before do
      allow(Flipper).to receive(:enabled?).with(:champva_send_ves_to_pega, anything).and_return(false)
    end

    form_numbers_and_classes.each do |form_number, form_class|
      context "when form_number is #{form_number}" do
        let(:parsed_form_data) do
          {
            'form_number' => form_number,
            'supporting_docs' => [
              { 'attachment_id' => 'doc1' },
              { 'attachment_id' => 'doc2' }
            ]
          }
        end

        it 'returns the correct file paths, metadata, and attachment IDs' do
          allow(controller).to receive(:get_attachment_ids_and_form).and_return([%w[doc1 doc2], form_class.new({})])
          allow_any_instance_of(IvcChampva::PdfFiller).to receive(:generate).and_return('file_path')
          allow(IvcChampva::MetadataValidator).to receive(:validate).and_return({ 'metadata' => {} })
          allow_any_instance_of(form_class).to receive(:handle_attachments).and_return(['file_path'])

          file_paths, metadata = controller.send(:get_file_paths_and_metadata, parsed_form_data)

          expect(file_paths).to eq(['file_path'])
          expect(metadata).to eq({ 'metadata' => {}, 'attachment_ids' => %w[doc1 doc2] })
        end
      end
    end
  end

  describe '#build_json' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    context 'when all status codes are 200' do
      it 'returns a status of 200' do
        expect(controller.send(:build_json, [200, 200], [nil, nil])).to eq({ json: {}, status: 200 })
      end
    end

    context 'when all status codes are 400' do
      it 'returns a status of 400 and an error message' do
        expect(controller.send(:build_json, [400, 400], %w[Error Error])).to eq({ json:
        { error_message: %w[Error Error] }, status: 400 })
      end
    end

    context 'when status codes include a 400' do
      it 'returns a status of 400' do
        expect(controller.send(:build_json, [200, 400], [nil, 'Error'])).to eq({ json:
        { error_message: [nil, 'Error'] }, status: 400 })
      end
    end

    context 'when status codes do not include 200 or 400' do
      it 'returns a status of 500' do
        expect(controller.send(:build_json, [300, 500], ['Multiple Choices', 'Error'])).to eq({ json:
        { error_message: 'An unknown error occurred while uploading document(s).' }, status: 500 })
      end
    end

    context 'when status codes are nil' do
      it 'handles nil values and returns a 500 error' do
        expect(controller.send(:build_json, nil, nil)).to eq({ json:
        { error_message: 'An unknown error occurred while uploading document(s).' }, status: 500 })
      end
    end
  end

  describe '#handle_file_uploads' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    forms.each do |form_file|
      form_id = form_file.gsub('vha_', '').gsub('.json', '').upcase
      form_numbers_and_classes[form_id]

      context 'with retry feature disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:champva_retry_logic_refactor, @current_user).and_return(false)
        end

        context "with form #{form_id}" do
          let(:form_id) { form_id }
          let(:parsed_form_data) do
            JSON.parse(Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', form_file).read)
          end
          let(:file_paths) { ['/path/to/file1.pdf', '/path/to/file2.pdf'] }
          let(:metadata) { { 'attachment_ids' => %w[id1 id2], 'uuid' => SecureRandom.uuid } }
          let(:file_uploader) { instance_double(IvcChampva::FileUploader, metadata:) }
          let(:error_response) { [[200, nil], [400, 'Upload failed']] }

          before do
            allow(controller).to receive(:get_file_paths_and_metadata).and_return([file_paths, metadata])
            allow(IvcChampva::FileUploader).to receive(:new).and_return(file_uploader)
          end

          context 'when require_all_s3_success feature is enabled' do
            let(:uploader) { IvcChampva::FileUploader.new(form_id, metadata, file_paths, true) }
            let(:mock_s3) { instance_double(IvcChampva::S3) }

            before do
              allow(Flipper).to receive(:enabled?).with(:champva_log_all_s3_uploads, @current_user).and_return(false)
              allow(IvcChampva::S3).to receive(:new).and_return(mock_s3)
              allow(IvcChampva::FileUploader).to receive(:new).and_call_original
            end

            it 'returns success when all uploads succeed' do
              allow(mock_s3).to receive(:put_object).and_return({ success: true })

              expect(uploader.handle_uploads).to eq([200, nil])

              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([200])
              expect(error_message).to eq([])
            end

            it 'raises a StandardError when any upload fails' do
              # need to test the FileUploader here since exceptions are being swallowed by the controller
              allow(mock_s3).to receive(:put_object).and_return({
                                                                  success: false,
                                                                  error_message: 'Upload failed'
                                                                })

              expect do
                uploader.handle_uploads
              end.to raise_error(StandardError, /failed to upload all documents/)

              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)

              expect(statuses).to eq([500])
              expect(error_message).to eq(['Server error occurred'])
            end
          end

          context 'when file uploads succeed' do
            before do
              allow(file_uploader).to receive(:handle_uploads).and_return([200, nil])
            end

            it 'returns success statuses and no error message' do
              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([200])
              expect(error_message).to eq([])
            end
          end

          context 'when file uploads fail with other errors' do
            before do
              allow(file_uploader).to receive(:handle_uploads).and_return(error_response)
            end

            it 'returns the error statuses and error message' do
              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([200, 400])
              expect(error_message).to eq([nil, 'Upload failed'])
            end
          end

          context 'when file uploads fail with other errors retry once' do
            subject(:result) { controller.send(:call_handle_file_uploads, form_id, parsed_form_data) }

            let(:expected_statuses) { [200, 400] } # All http codes
            let(:expected_error_message) { [nil, 'Upload failed'] } # All error message strings

            before do
              allow(file_uploader).to receive(:handle_uploads).and_return(error_response)
            end

            it 'returns the error statuses and error message' do
              expect(result).to eq([expected_statuses, expected_error_message])
            end
          end

          context 'when a file repeatedly fails to load' do
            before do
              allow(file_uploader).to receive(:handle_uploads).and_raise(StandardError.new('Unable to find file'))
            end

            it 'handles 400 status with error message' do
              allow(file_uploader).to receive(:handle_uploads).and_return([400, 'Upload failed'])
              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([400])
              expect(error_message).to eq(['Upload failed'])
            end

            it 'handles server error status codes' do
              allow(file_uploader).to receive(:handle_uploads).and_return([500, 'Server error occurred'])
              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([500])
              expect(error_message).to eq(['Server error occurred'])
            end

            it 'retries handle_uploads once and returns an error message' do
              # Expect handle_uploads to be called twice due to one retry
              expect(file_uploader).to receive(:handle_uploads).at_least(:twice)
              _statuses, _error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              # This expectation causes the `.to receive(:handle_uploads)` count to increment by 1:
              expect { file_uploader.handle_uploads }.to raise_error(StandardError, /Unable to find file/)
            end
          end
        end
      end

      context 'with retry feature enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:champva_retry_logic_refactor, @current_user).and_return(true)
        end

        context "with form #{form_id}" do
          let(:form_id) { form_id }
          let(:parsed_form_data) do
            JSON.parse(Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', form_file).read)
          end
          let(:file_paths) { ['/path/to/file1.pdf', '/path/to/file2.pdf'] }
          let(:metadata) { { 'attachment_ids' => %w[id1 id2], 'uuid' => SecureRandom.uuid } }
          let(:file_uploader) { instance_double(IvcChampva::FileUploader, metadata:) }
          let(:error_response) { [[200, nil], [400, 'Upload failed']] }

          before do
            allow(controller).to receive(:get_file_paths_and_metadata).and_return([file_paths, metadata])
            allow(IvcChampva::FileUploader).to receive(:new).and_return(file_uploader)
          end

          context 'when require_all_s3_success feature is enabled' do
            let(:uploader) { IvcChampva::FileUploader.new(form_id, metadata, file_paths, true) }
            let(:mock_s3) { instance_double(IvcChampva::S3) }

            before do
              allow(Flipper).to receive(:enabled?).with(:champva_log_all_s3_uploads, @current_user).and_return(false)
              allow(IvcChampva::S3).to receive(:new).and_return(mock_s3)
              allow(IvcChampva::FileUploader).to receive(:new).and_call_original
            end

            it 'returns success when all uploads succeed' do
              allow(mock_s3).to receive(:put_object).and_return({ success: true })

              expect(uploader.handle_uploads).to eq([200, nil])

              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([200])
              expect(error_message).to eq([])
            end

            it 'raises a StandardError when any upload fails' do
              # need to test the FileUploader here since exceptions are being swallowed by the controller
              allow(mock_s3).to receive(:put_object).and_return({
                                                                  success: false,
                                                                  error_message: 'Upload failed'
                                                                })

              expect do
                uploader.handle_uploads
              end.to raise_error(StandardError, /failed to upload all documents/)

              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)

              expect(statuses).to eq([500])
              expect(error_message).to eq(['Server error occurred'])
            end
          end

          context 'when file uploads succeed' do
            before do
              allow(file_uploader).to receive(:handle_uploads).and_return([200, nil])
            end

            it 'returns success statuses and no error message' do
              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([200])
              expect(error_message).to eq([])
            end
          end

          context 'when file uploads fail with other errors' do
            before do
              allow(file_uploader).to receive(:handle_uploads).and_return(error_response)
            end

            it 'returns the error statuses and error message' do
              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([200, 400])
              expect(error_message).to eq([nil, 'Upload failed'])
            end
          end

          context 'when file uploads fail with other errors retry once' do
            subject(:result) { controller.send(:call_handle_file_uploads, form_id, parsed_form_data) }

            let(:expected_statuses) { [200, 400] } # All http codes
            let(:expected_error_message) { [nil, 'Upload failed'] } # All error message strings

            before do
              allow(file_uploader).to receive(:handle_uploads).and_return(error_response)
            end

            it 'returns the error statuses and error message' do
              expect(result).to eq([expected_statuses, expected_error_message])
            end
          end

          context 'when a file repeatedly fails to load' do
            before do
              allow(file_uploader).to receive(:handle_uploads).and_raise(StandardError.new('Unable to find file'))
            end

            it 'handles 400 status with error message' do
              allow(file_uploader).to receive(:handle_uploads).and_return([400, 'Upload failed'])
              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([400])
              expect(error_message).to eq(['Upload failed'])
            end

            it 'handles server error status codes' do
              allow(file_uploader).to receive(:handle_uploads).and_return([500, 'Server error occurred'])
              statuses, error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              expect(statuses).to eq([500])
              expect(error_message).to eq(['Server error occurred'])
            end

            it 'retries handle_uploads once and returns an error message' do
              # Expect handle_uploads to be called twice due to one retry
              expect(file_uploader).to receive(:handle_uploads).at_least(:twice)
              _statuses, _error_message = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
              # This expectation causes the `.to receive(:handle_uploads)` count to increment by 1:
              expect { file_uploader.handle_uploads }.to raise_error(StandardError, /Unable to find file/)
            end
          end
        end
      end
    end
  end

  describe '#should_retry?' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    it 'returns true for retryable errors within max attempts' do
      retryable_errors = [
        'failed to generate file',
        'no such file or directory',
        'an error occurred while verifying stamp: some error',
        'unable to find file'
      ]

      retryable_errors.each do |error_message|
        expect(controller.send(:should_retry?, error_message.downcase, 1, 3)).to be true
      end
    end

    it 'returns false for non-retryable errors' do
      non_retryable_errors = [
        'some other error',
        'random error message'
      ]

      non_retryable_errors.each do |error_message|
        expect(controller.send(:should_retry?, error_message.downcase, 1, 3)).to be false
      end
    end

    it 'returns false when max attempts exceeded' do
      error_message = 'failed to generate file'
      expect(controller.send(:should_retry?, error_message.downcase, 4, 3)).to be false
    end
  end

  describe '#handle_file_uploads_with_refactored_retry' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:form_id) { 'vha_10_10d' }
    let(:parsed_form_data) do
      JSON.parse(Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json').read)
    end
    let(:file_paths) { ['/path/to/file1.pdf', '/path/to/file2.pdf'] }
    let(:metadata) { { 'attachment_ids' => %w[id1 id2], 'uuid' => SecureRandom.uuid } }
    let(:file_uploader) { instance_double(IvcChampva::FileUploader, metadata:) }

    before do
      allow(controller).to receive(:get_file_paths_and_metadata).and_return([file_paths, metadata])
      allow(IvcChampva::FileUploader).to receive(:new).and_return(file_uploader)
      allow(controller).to receive(:instance_variable_get).with('@current_user').and_return(nil)
    end

    context 'when the retry method fails outside the retry block' do
      before do
        allow(IvcChampva::Retry).to receive(:do).and_raise(StandardError.new('Catastrophic failure'))
      end

      it 'raises the error' do
        expect do
          controller.send(:handle_file_uploads_with_refactored_retry, form_id, parsed_form_data)
        end.to raise_error(StandardError, 'Catastrophic failure')
      end
    end

    context 'when the retry method executes successfully' do
      before do
        allow(IvcChampva::Retry).to receive(:do).and_yield
        allow(file_uploader).to receive(:handle_uploads).and_return([[200, nil]])
      end

      it 'returns the values from handle_uploads' do
        statuses, error_messages = controller.send(:handle_file_uploads_with_refactored_retry, form_id,
                                                   parsed_form_data)
        expect(statuses).to eq([200])
        expect(error_messages).to eq([nil])
      end
    end
  end

  describe '#upload_form_with_refactored_retry' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:form_id) { 'vha_10_10d' }
    let(:file_paths) { ['/path/to/file1.pdf', '/path/to/file2.pdf'] }
    let(:metadata) { { 'attachment_ids' => %w[id1 id2], 'uuid' => SecureRandom.uuid } }
    let(:file_uploader) { instance_double(IvcChampva::FileUploader, metadata:) }

    before do
      allow(IvcChampva::FileUploader).to receive(:new).and_return(file_uploader)
      allow(controller).to receive(:instance_variable_get).with('@current_user').and_return(nil)
    end

    context 'when the retry method fails outside the retry block' do
      before do
        allow(IvcChampva::Retry).to receive(:do).and_raise(StandardError.new('Catastrophic failure'))
      end

      it 'raises the error' do
        expect do
          controller.send(:upload_form_with_refactored_retry, form_id, file_paths, metadata)
        end.to raise_error(StandardError, 'Catastrophic failure')
      end
    end

    context 'when the retry method executes successfully' do
      before do
        allow(IvcChampva::Retry).to receive(:do).and_yield
        allow(file_uploader).to receive(:handle_uploads).and_return([[200, nil]])
      end

      it 'returns the values from handle_uploads' do
        statuses, error_messages = controller.send(:upload_form_with_refactored_retry, form_id, file_paths, metadata)
        expect(statuses).to eq([200])
        expect(error_messages).to eq([nil])
      end
    end
  end

  describe '#add_blank_doc_and_stamp integration' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:parsed_form_data) { { 'form_number' => '10-7959A', 'supporting_docs' => [] } }

    # Basic test form class with stamp_metadata method to verify
    # it properly gates the functionality
    let(:form) do
      instance_double(IvcChampva::VHA107959a,
                      form_id: '10-7959A',
                      methods: [:stamp_metadata],
                      stamp_metadata: { metadata: { 'test_key' => 'test_value' }, attachment_id: 'Test Attachment' })
    end

    it 'creates and adds a supporting document' do
      # Mock out the PDF operations to avoid actually creating files
      expect(IvcChampva::PdfStamper).to receive(:stamp_metadata_items)
      expect(controller).to receive(:create_custom_attachment).and_return({ 'attachment_id' => 'doc1' })

      # Check that a supporting doc gets added to the form_data
      expect do
        controller.send(:add_blank_doc_and_stamp, form, parsed_form_data)
      end.to change { parsed_form_data['supporting_docs'].length }.from(0).to(1)

      expect(parsed_form_data['supporting_docs']).to include({ 'attachment_id' => 'doc1' })
    end
  end

  describe '#add_blank_doc_and_stamp without stamp_metadata method' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:form) { instance_double(IvcChampva::VHA1010d) }
    let(:parsed_form_data) { { 'form_number' => '10-10D' } }

    before do
      allow(form).to receive(:methods).and_return([])
    end

    it 'does nothing when form has no stamp_metadata method' do
      expect(IvcChampva::PdfStamper).not_to receive(:stamp_metadata_items)

      controller.send(:add_blank_doc_and_stamp, form, parsed_form_data)
    end
  end

  describe '#validate_mpi_profiles' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:parsed_form_data) do
      JSON.parse(Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json').read)
    end
    let(:mock_mpi_service) { instance_double(IvcChampva::MPIService) }

    before do
      allow(IvcChampva::MPIService).to receive(:new).and_return(mock_mpi_service)
      allow(mock_mpi_service).to receive(:validate_profiles)
      allow(controller).to receive(:instance_variable_get).with('@current_user').and_return(nil)
    end

    context 'when flipper is enabled and form_id is vha_10_10d' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:champva_mpi_validation, nil)
          .and_return(true)
      end

      it 'calls MpiService.validate_profiles' do
        controller.send(:validate_mpi_profiles, parsed_form_data, 'vha_10_10d')

        expect(IvcChampva::MPIService).to have_received(:new).with(no_args)
        expect(mock_mpi_service).to have_received(:validate_profiles).with(parsed_form_data)
      end
    end

    context 'when flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:champva_mpi_validation, nil)
          .and_return(false)
      end

      it 'does not call MpiService.validate_profiles' do
        controller.send(:validate_mpi_profiles, parsed_form_data, 'vha_10_10d')

        expect(IvcChampva::MPIService).not_to have_received(:new)
        expect(mock_mpi_service).not_to have_received(:validate_profiles)
      end
    end

    context 'when form_id is not vha_10_10d' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:champva_mpi_validation, nil)
          .and_return(true)
      end

      it 'does not call MpiService.validate_profiles' do
        controller.send(:validate_mpi_profiles, parsed_form_data, 'vha_10_7959c')

        expect(IvcChampva::MPIService).not_to have_received(:new)
        expect(mock_mpi_service).not_to have_received(:validate_profiles)
      end
    end

    context 'when MpiService raises an error' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:champva_mpi_validation, nil)
          .and_return(true)
        allow(mock_mpi_service).to receive(:validate_profiles)
          .and_raise(StandardError.new('MPI service error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and does not raise' do
        expect do
          controller.send(:validate_mpi_profiles, parsed_form_data, 'vha_10_10d')
        end.not_to raise_error

        expect(Rails.logger).to have_received(:error).with('Error validating MPI profiles: MPI service error')
      end
    end
  end

  describe '#generate_ves_json_file' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:parsed_form_data) do
      JSON.parse(Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json').read)
    end
    let(:mock_form) { double('Form', form_id: 'vha_10_10d', uuid: 'test-uuid-123') }
    let(:mock_ves_request) { double('VesRequest') }

    before do
      allow(controller).to receive(:instance_variable_get).with('@current_user').and_return(nil)
      allow(IvcChampva::VesDataFormatter).to receive(:format_for_request).and_return(mock_ves_request)
      allow(mock_ves_request).to receive(:to_json).and_return('{"test": "data"}')
      allow(File).to receive(:write)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    it 'generates VES JSON file and returns file path' do
      expected_path = Rails.root.join("tmp/#{mock_form.uuid}_#{mock_form.form_id}_ves.json").to_s
      result = controller.send(:generate_ves_json_file, mock_form, parsed_form_data)

      expect(result).to eq(expected_path)
      expect(IvcChampva::VesDataFormatter).to have_received(:format_for_request).with(parsed_form_data)
      expect(File).to have_received(:write).with(
        expected_path,
        '{"test": "data"}'
      )
      expect(Rails.logger).to have_received(:info).with(
        "VES JSON file generated for form #{mock_form.form_id}: #{expected_path}"
      )
    end

    context 'when VES data generation fails' do
      before do
        allow(IvcChampva::VesDataFormatter).to receive(:format_for_request)
          .and_raise(StandardError.new('VES formatting error'))
      end

      it 'logs the error and returns nil' do
        result = controller.send(:generate_ves_json_file, mock_form, parsed_form_data)

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error)
          .with('Error generating VES JSON file for form vha_10_10d: VES formatting error')
        expect(File).not_to have_received(:write)
      end
    end
  end

  describe '#get_file_paths_and_metadata VES JSON integration' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:parsed_form_data) do
      JSON.parse(Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json').read)
    end
    let(:mock_form) { double('Form', form_id: 'vha_10_10d', uuid: 'test-uuid-123', data: {}, metadata: {}) }

    before do
      allow(controller).to receive(:instance_variable_get).with('@current_user').and_return(nil)
      allow(controller).to receive_messages(get_attachment_ids_and_form: [['doc1'], mock_form],
                                            should_generate_ves_json?: false)
      allow(controller).to receive(:generate_ves_json_file)
      allow(IvcChampva::FormVersionManager).to receive(:get_legacy_form_id).and_return('vha_10_10d')
      allow_any_instance_of(IvcChampva::PdfFiller).to receive(:generate).and_return('test_path.pdf')
      allow(IvcChampva::MetadataValidator).to receive(:validate).and_return({})
      allow(mock_form).to receive(:handle_attachments).and_return(['test_path.pdf'])
    end

    context 'when VES JSON generation conditions are met' do
      let(:expected_ves_path) { Rails.root.join('tmp', 'test-uuid-123_vha_10_10d_ves.json').to_s }

      before do
        allow(controller).to receive(:should_generate_ves_json?).with('vha_10_10d').and_return(true)
        allow(controller).to receive(:generate_ves_json_file).and_return(expected_ves_path)
      end

      it 'generates VES JSON file and adds it to file_paths and attachment_ids' do
        file_paths, metadata = controller.send(:get_file_paths_and_metadata, parsed_form_data)

        expect(controller).to have_received(:should_generate_ves_json?).with('vha_10_10d')
        expect(controller).to have_received(:generate_ves_json_file).with(mock_form, parsed_form_data)
        expect(file_paths).to include(expected_ves_path)
        expect(metadata['attachment_ids']).to include('VES JSON')
      end
    end

    context 'when VES JSON generation conditions are not met' do
      before do
        allow(controller).to receive(:should_generate_ves_json?).with('vha_10_10d').and_return(false)
      end

      it 'does not generate VES JSON file' do
        file_paths, metadata = controller.send(:get_file_paths_and_metadata, parsed_form_data)

        expect(controller).to have_received(:should_generate_ves_json?).with('vha_10_10d')
        expect(controller).not_to have_received(:generate_ves_json_file)
        expect(file_paths).not_to include('VES JSON')
        expect(metadata['attachment_ids']).not_to include('VES JSON')
      end
    end

    context 'when VES JSON generation fails' do
      before do
        allow(controller).to receive(:should_generate_ves_json?).with('vha_10_10d').and_return(true)
        allow(controller).to receive(:generate_ves_json_file).and_return(nil)
      end

      it 'does not add VES JSON to file_paths or attachment_ids' do
        file_paths, metadata = controller.send(:get_file_paths_and_metadata, parsed_form_data)

        expect(controller).to have_received(:generate_ves_json_file).with(mock_form, parsed_form_data)
        expect(file_paths).not_to include(nil)
        expect(metadata['attachment_ids']).not_to include('VES JSON')
      end
    end
  end

  describe '#launch_background_job' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:file_path) { '/tmp/some_file.pdf' }
    let(:attachment_guid) { '12345' }
    let(:mock_file) do
      double('UploadedFile',
             original_filename: 'some_file.pdf',
             read: 'content',
             path: file_path,
             content_type: 'application/pdf').tap do |file|
        allow(file).to receive(:respond_to?).with(:original_filename).and_return(true)
        allow(file).to receive(:respond_to?).with(:content_type).and_return(true)
      end
    end
    let(:attachment) { double('PersistentAttachments::MilitaryRecords', id: 123, file: mock_file, guid: attachment_guid, to_pdf: file_path) }
    let(:tmpfile) { double('Tempfile', path: file_path, binmode: true, write: true, flush: true) }

    context 'when form_id is 10-7959A' do
      let(:form_id) { '10-7959A' }

      context 'when OCR feature is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit, anything).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:champva_enable_llm_on_submit, anything).and_return(true)
        end

        it 'queues TesseractOcrLoggerJob with correct arguments' do
          job = class_double(IvcChampva::TesseractOcrLoggerJob).as_stubbed_const
          expect(job).to receive(:perform_async).with(
            form_id,
            attachment_guid,
            attachment.id,
            'EOB',
            anything
          )

          controller.send(:launch_background_job, attachment, form_id, 'EOB')
        end

        it 'queues LlmLoggerJob with correct arguments' do
          llm_job = class_double(IvcChampva::LlmLoggerJob).as_stubbed_const
          expect(llm_job).to receive(:perform_async).with(
            form_id,
            attachment_guid,
            attachment.id, # attachment record ID instead of PDF path
            'EOB',
            anything
          )

          controller.send(:launch_background_job, attachment, form_id, 'EOB')
        end
      end

      context 'when OCR feature is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit, anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:champva_enable_llm_on_submit, anything).and_return(false)
        end

        it 'does not queue TesseractOcrLoggerJob' do
          job = class_double(IvcChampva::TesseractOcrLoggerJob).as_stubbed_const
          expect(job).not_to receive(:perform_async)

          controller.send(:launch_background_job, attachment, form_id, 'EOB')
        end

        it 'does not queue LlmLoggerJob' do
          llm_job = class_double(IvcChampva::LlmLoggerJob).as_stubbed_const
          expect(llm_job).not_to receive(:perform_async)

          controller.send(:launch_background_job, attachment, form_id, 'EOB')
        end
      end
    end

    context 'when form_id is not 10-7959A' do
      let(:form_id) { '10-10d' }

      context 'when OCR feature is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:champva_enable_ocr_on_submit, anything).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:champva_enable_llm_on_submit, anything).and_return(true)
        end

        it 'does not queue TesseractOcrLoggerJob' do
          job = class_double(IvcChampva::TesseractOcrLoggerJob).as_stubbed_const
          expect(job).not_to receive(:perform_async)

          controller.send(:launch_background_job, attachment, form_id, 'EOB')
        end

        it 'does not queue LlmLoggerJob' do
          llm_job = class_double(IvcChampva::LlmLoggerJob).as_stubbed_const
          expect(llm_job).not_to receive(:perform_async)

          controller.send(:launch_background_job, attachment, form_id, 'EOB')
        end
      end
    end
  end

  describe '#tempfile_from_attachment' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:form_id) { '10-7959A' }
    let(:file_content) { 'test file content' }

    context 'when attachment.file responds to original_filename' do
      let(:mock_file) do
        double('UploadedFile',
               original_filename: 'some_file.gif',
               read: file_content)
      end

      let(:attachment) do
        instance_double(PersistentAttachments::MilitaryRecords, file: mock_file)
      end

      it 'creates a tempfile with the original filename and random code' do
        tmpfile = controller.send(:tempfile_from_attachment, attachment, form_id)

        expect(tmpfile).to be_a(Tempfile)
        expect(File.basename(tmpfile.path)).to match(/^10-7959A_attachment_[\w-]+\.gif$/)
        tmpfile.rewind
        expect(tmpfile.read).to eq(file_content)
        tmpfile.close
        tmpfile.unlink
      end
    end

    context 'when attachment.file does not respond to original_filename' do
      let(:mock_file) do
        double('File',
               path: '/tmp/some_other_file.png',
               read: file_content)
      end

      let(:attachment) do
        instance_double(PersistentAttachments::MilitaryRecords, file: mock_file)
      end

      it 'creates a tempfile with the basename and random code' do
        tmpfile = controller.send(:tempfile_from_attachment, attachment, form_id)

        expect(tmpfile).to be_a(Tempfile)
        expect(File.basename(tmpfile.path)).to match(/^10-7959A_attachment_[\w-]+\.png$/)
        tmpfile.rewind
        expect(tmpfile.read).to eq(file_content)
        tmpfile.close
        tmpfile.unlink
      end
    end
  end
end
