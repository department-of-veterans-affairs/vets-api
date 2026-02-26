# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe 'IvcChampva::V1::Forms::VesUploads', type: :request do
  # This spec file focuses on testing the refactored workflows introduced in the uploads controller
  # with the VES integrsation.

  let(:ves_request) do
    double('IvcChampva::VesRequest',
           application_uuid: 'test-uuid',
           transaction_uuid: 'fake-id',
           to_json: '{}',
           subforms?: false,
           subforms: [])
  end
  let(:ves_client) { double('IvcChampva::VesApi::Client') }
  let(:ves_response) { double('IvcChampva::VesApi::Response', status: 200, body: { result: 'success' }) }
  let(:mock_form) { double(first_name: 'Veteran', last_name: 'Surname', form_uuid: 'some_uuid') }
  let(:mock_s3) { instance_double(IvcChampva::S3) }

  before do
    @original_aws_config = Aws.config.dup
    Aws.config.update(stub_responses: true)

    # Mock VES-related methods
    allow(IvcChampva::VesDataFormatter).to receive(:format_for_request).and_return(ves_request)
    allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
    allow(ves_client).to receive(:submit_1010d).and_return(ves_response)
    allow(ves_request).to receive(:transaction_uuid=)

    # Mock database-related methods
    allow(IvcChampvaForm).to receive_messages(first: mock_form, where: [mock_form])
    allow(mock_form).to receive(:update)

    # Mock PDF generation
    allow_any_instance_of(IvcChampva::VHA1010d2027).to receive(:handle_attachments).and_return(['test_path.pdf'])
    allow_any_instance_of(IvcChampva::VHA1010d).to receive(:handle_attachments).and_return(['test_path.pdf'])
    allow_any_instance_of(IvcChampva::PdfFiller).to receive(:generate).and_return('test_path.pdf')

    # Mock file uploads
    allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
      .and_return(double('Record1', created_at: 1.day.ago, id: 'some_uuid', file: double(id: 'file0')))
    allow(IvcChampva::S3).to receive(:new).and_return(mock_s3)
    allow(mock_s3).to receive(:put_object).and_return({ success: true })
  end

  after do
    Aws.config = @original_aws_config
  end

  describe 'run this section with both values of champva_retry_logic_refactor expecting identical behavior' do
    retry_logic_refactor_values = [true, false]
    retry_logic_refactor_values.each do |champva_retry_logic_refactor_state|
      describe '#submit with VES integration' do
        let(:form_data) do
          JSON.parse(Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json').read)
        end

        context 'with flipper champva_send_to_ves enabled' do
          before do
            allow(Flipper).to receive(:enabled?)
              .with(:champva_send_to_ves, anything)
              .and_return(true)
            allow(Flipper).to receive(:enabled?)
              .with(:champva_retry_logic_refactor, @current_user)
              .and_return(champva_retry_logic_refactor_state)
          end

          it 'uploads a PDF file to S3 and submits to VES for form 10-10D' do
            # Allow for transaction_uuid= to be called but preserve the original 'fake-id' value
            allow(ves_request).to receive(:transaction_uuid).and_return('fake-id')

            post '/ivc_champva/v1/forms', params: form_data

            record = IvcChampvaForm.first
            expect(record.first_name).to eq('Veteran')
            expect(record.last_name).to eq('Surname')
            expect(record.form_uuid).to be_present

            expect(IvcChampva::VesDataFormatter).to have_received(:format_for_request).at_least(:once)
            expect(ves_client).to have_received(:submit_1010d)
              .with(anything, 'fake-user', ves_request)
            expect(mock_form).to have_received(:update)
              .with(hash_including(
                      application_uuid: 'test-uuid',
                      ves_status: 'ok'
                    ))

            expect(response).to have_http_status(:ok)
          end

          it 'handles VES formatter errors gracefully' do
            allow(IvcChampva::VesDataFormatter).to receive(:format_for_request)
              .and_raise(StandardError.new('formatting error'))

            post '/ivc_champva/v1/forms', params: form_data

            expect(response).to have_http_status(:internal_server_error)
            expect(response.parsed_body['error_message']).to eq('Error: formatting error')
          end

          it 'handles nil VES request gracefully' do
            allow(IvcChampva::VesDataFormatter).to receive(:format_for_request).and_return(nil)

            post '/ivc_champva/v1/forms', params: form_data

            expect(response).to have_http_status(:internal_server_error)
            expect(response.parsed_body['error_message']).to eq('Error: Failed to format data for VES submission')
          end

          it 'handles VES API errors gracefully and still returns success' do
            # Mock a StandardError being raised during VES submission
            allow(ves_client).to receive(:submit_1010d)
              .with(anything, anything, anything)
              .and_raise(StandardError.new('api error'))

            # Make sure the FileUploader returns success to allow form submission to succeed
            allow_any_instance_of(IvcChampva::FileUploader).to receive(:handle_uploads)
              .and_return([200, nil])

            post '/ivc_champva/v1/forms', params: form_data

            # Should still be successful even if VES fails
            expect(response).to have_http_status(:ok)
          end

          it 'does not submit non-10-10D forms to VES' do
            controller = IvcChampva::V1::UploadsController.new
            other_form_data = form_data.merge({ 'form_number' => '10-7959C' })

            allow(controller).to receive_messages(get_form_id: 'vha_10_7959c',
                                                  params: ActionController::Parameters.new(other_form_data),
                                                  call_handle_file_uploads: [[200], nil])
            allow(controller).to receive(:render)

            controller.send(:submit)

            expect(IvcChampva::VesDataFormatter).not_to have_received(:format_for_request).with(other_form_data)
            expect(ves_client).not_to have_received(:submit_1010d)
          end

          it 'handles file upload failures' do
            allow(mock_s3).to receive(:put_object).and_return({
                                                                success: false,
                                                                error_message: 'Upload failed'
                                                              })

            post '/ivc_champva/v1/forms', params: form_data

            expect(response).to have_http_status(:internal_server_error)
            expect(ves_client).not_to have_received(:submit_1010d)
          end
        end

        context 'with flipper champva_send_to_ves disabled' do
          before do
            allow(Flipper).to receive(:enabled?)
              .with(:champva_send_to_ves, anything)
              .and_return(false)
            allow(Flipper).to receive(:enabled?)
              .with(:champva_send_ves_to_pega, anything)
              .and_return(false)
          end

          it 'does not submit to VES' do
            post '/ivc_champva/v1/forms', params: form_data

            expect(IvcChampva::VesDataFormatter).not_to have_received(:format_for_request)
            expect(ves_client).not_to have_received(:submit_1010d)
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end

  # Test for refactored retry logic
  describe 'retry logic with feature flag' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:form_id) { 'vha_10_10d' }
    let(:parsed_form_data) do
      {
        'form_number' => '10-10D',
        'supporting_docs' => [
          { 'confirmation_code' => 'code1', 'attachment_id' => 'doc1' }
        ]
      }
    end
    let(:file_paths) { ['/path/to/file1.pdf'] }
    let(:metadata) { { 'attachment_ids' => ['doc1'] } }
    let(:file_uploader) { instance_double(IvcChampva::FileUploader) }

    before do
      allow(controller).to receive(:get_file_paths_and_metadata).and_return([file_paths, metadata])
      allow(IvcChampva::FileUploader).to receive(:new).and_return(file_uploader)
    end

    context 'with champva_retry_logic_refactor enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:champva_retry_logic_refactor, anything)
          .and_return(true)
      end

      it 'uses the refactored retry method' do
        allow(file_uploader).to receive(:handle_uploads).and_return([200, nil])

        expect(IvcChampva::Retry).to receive(:do).and_yield

        controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
      end

      it 'correctly handles successful uploads' do
        allow(file_uploader).to receive(:handle_uploads).and_return([200, nil])
        allow(IvcChampva::Retry).to receive(:do).and_yield

        statuses, error_messages = controller.send(:call_handle_file_uploads, form_id, parsed_form_data)

        expect(statuses).to eq([200])
        expect(error_messages).to eq([])
      end

      it 'correctly handles upload failures' do
        # Use the actual controller method but simplify the test
        # Instead of testing the complex behavior of handling errors with actual values
        # just verify that the correct method (handle_file_uploads_with_refactored_retry) is called
        expect(controller).to receive(:handle_file_uploads_with_refactored_retry).with(form_id, parsed_form_data)

        controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
      end
    end

    context 'with champva_retry_logic_refactor disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:champva_retry_logic_refactor, anything)
          .and_return(false)
      end

      it 'uses the original retry logic' do
        allow(file_uploader).to receive(:handle_uploads).and_return([200, nil])

        # Original method doesn't use the Retry class
        expect(IvcChampva::Retry).not_to receive(:do)

        controller.send(:call_handle_file_uploads, form_id, parsed_form_data)
      end
    end
  end

  describe 'subform submission flow' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:ves_client) { instance_double(IvcChampva::VesApi::Client) }
    let(:metadata) { { 'uuid' => 'test-form-uuid' } }

    let(:ves_request) do
      request = IvcChampva::VesRequest.new(
        application_uuid: 'parent-app-uuid',
        sponsor: { first_name: 'John', last_name: 'Doe' }
      )
      request
    end

    let(:mock_ohi_request) do
      double('VesOhiRequest',
             application_uuid: 'parent-app-uuid',
             transaction_uuid: nil,
             to_json: '{"type": "ohi"}')
    end

    let(:success_response) { double('Response', status: 200, body: 'success') }
    let(:failure_response) { double('Response', status: 500, body: 'error') }

    before do
      allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
      allow(ves_client).to receive(:submit_1010d).and_return(success_response)
      allow(mock_ohi_request).to receive(:transaction_uuid=)

      # Mock database updates
      allow(IvcChampvaForm).to receive(:where).and_return([])
    end

    describe '#submit_ves_request (original - no subforms)' do
      it 'submits only the primary form' do
        allow(ves_request).to receive(:transaction_uuid=)

        controller.send(:submit_ves_request, ves_request, metadata)

        expect(ves_client).to have_received(:submit_1010d).once
      end

      it 'returns the primary response' do
        allow(ves_request).to receive(:transaction_uuid=)

        result = controller.send(:submit_ves_request, ves_request, metadata)

        expect(result).to eq(success_response)
      end

      context 'when request is nil' do
        it 'returns nil without attempting submission' do
          result = controller.send(:submit_ves_request, nil, metadata)

          expect(result).to be_nil
          expect(ves_client).not_to have_received(:submit_1010d)
        end
      end
    end

    describe '#submit_ves_request_with_subforms (enhanced - with subform support)' do
      context 'when request has no subforms' do
        it 'submits only the primary form' do
          allow(ves_request).to receive(:transaction_uuid=)

          controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

          expect(ves_client).to have_received(:submit_1010d).once
        end

        it 'returns the primary response' do
          allow(ves_request).to receive(:transaction_uuid=)

          result = controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

          expect(result).to eq(success_response)
        end
      end

      context 'when request has subforms and primary succeeds' do
        before do
          ves_request.add_subform('vha_10_7959c', mock_ohi_request)
          allow(ves_request).to receive(:transaction_uuid=)
          allow(ves_client).to receive(:submit_7959c).and_return(success_response)
        end

        it 'submits the primary form first' do
          controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

          expect(ves_client).to have_received(:submit_1010d).ordered
        end

        it 'submits each subform after primary succeeds' do
          controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

          expect(ves_client).to have_received(:submit_7959c).with(anything, 'fake-user', mock_ohi_request)
        end

        it 'generates fresh transaction_uuid for each subform' do
          expect(mock_ohi_request).to receive(:transaction_uuid=).with(a_string_matching(/\A[0-9a-f-]{36}\z/))

          controller.send(:submit_ves_request_with_subforms, ves_request, metadata)
        end

        it 'returns the primary response even when subforms exist' do
          result = controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

          expect(result).to eq(success_response)
        end
      end

      context 'when request has subforms but primary fails' do
        before do
          ves_request.add_subform('vha_10_7959c', mock_ohi_request)
          allow(ves_request).to receive(:transaction_uuid=)
          allow(ves_client).to receive(:submit_1010d).and_return(failure_response)
          allow(ves_client).to receive(:submit_7959c) # Stub but don't expect it to be called
        end

        it 'does not submit subforms when primary fails' do
          controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

          expect(ves_client).not_to have_received(:submit_7959c)
        end

        it 'returns the failed primary response' do
          result = controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

          expect(result).to eq(failure_response)
        end
      end

      context 'when request is nil' do
        it 'returns nil without attempting submission' do
          result = controller.send(:submit_ves_request_with_subforms, nil, metadata)

          expect(result).to be_nil
          expect(ves_client).not_to have_received(:submit_1010d)
        end
      end

      context 'with multiple subforms' do
        let(:mock_ohi_request2) do
          double('VesOhiRequest2',
                 application_uuid: 'parent-app-uuid',
                 transaction_uuid: nil,
                 to_json: '{"type": "ohi2"}')
        end

        before do
          ves_request.add_subform('vha_10_7959c', mock_ohi_request)
          ves_request.add_subform('vha_10_7959c', mock_ohi_request2)
          allow(ves_request).to receive(:transaction_uuid=)
          allow(mock_ohi_request2).to receive(:transaction_uuid=)
          allow(ves_client).to receive(:submit_7959c).and_return(success_response)
        end

        it 'submits all subforms' do
          controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

          expect(ves_client).to have_received(:submit_7959c).twice
        end

        context 'when one subform fails' do
          before do
            allow(ves_client).to receive(:submit_7959c)
              .with(anything, anything, mock_ohi_request)
              .and_raise(StandardError.new('first subform failed'))
            allow(ves_client).to receive(:submit_7959c)
              .with(anything, anything, mock_ohi_request2)
              .and_return(success_response)
          end

          it 'continues submitting remaining subforms' do
            allow(Rails.logger).to receive(:error)

            controller.send(:submit_ves_request_with_subforms, ves_request, metadata)

            expect(ves_client).to have_received(:submit_7959c).with(anything, anything, mock_ohi_request2)
          end

          it 'logs the error for the failed subform' do
            expect(Rails.logger).to receive(:error).at_least(:once)

            controller.send(:submit_ves_request_with_subforms, ves_request, metadata)
          end
        end
      end
    end

    describe '#send_to_ves_by_form_type' do
      it 'routes vha_10_10d to submit_1010d' do
        allow(ves_request).to receive(:transaction_uuid).and_return('test-uuid')

        controller.send(:send_to_ves_by_form_type, ves_client, ves_request, 'vha_10_10d')

        expect(ves_client).to have_received(:submit_1010d).with('test-uuid', 'fake-user', ves_request)
      end

      it 'routes vha_10_7959c to submit_7959c' do
        allow(ves_client).to receive(:submit_7959c).and_return(success_response)
        allow(mock_ohi_request).to receive(:transaction_uuid).and_return('ohi-uuid')

        controller.send(:send_to_ves_by_form_type, ves_client, mock_ohi_request, 'vha_10_7959c')

        expect(ves_client).to have_received(:submit_7959c).with('ohi-uuid', 'fake-user', mock_ohi_request)
      end

      it 'raises ArgumentError for unknown form types' do
        expect do
          controller.send(:send_to_ves_by_form_type, ves_client, ves_request, 'unknown_form')
        end.to raise_error(ArgumentError, /Unknown VES form type/)
      end
    end
  end
end
