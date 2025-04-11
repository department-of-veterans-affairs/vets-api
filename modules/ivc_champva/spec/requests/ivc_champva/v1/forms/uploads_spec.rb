# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

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
    allow(ves_request).to receive(:transaction_uuid).and_return('78444a0b-3ac8-454d-a28d-8d63cddd0d3b')
    allow(ves_request).to receive(:transaction_uuid=)
    allow(ves_request).to receive(:application_uuid).and_return('test-uuid')
    allow(ves_request).to receive(:to_json).and_return('{}')
  end

  after do
    Aws.config = @original_aws_config
  end

  describe '#submit with flipper champva_send_to_ves enabled' do
    before do
      allow(Flipper).to receive(:enabled?)
        .with(:champva_send_to_ves, @current_user)
        .and_return(true)
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

      context 'when environment is production' do
        it 'does not do any VES processing' do
          with_settings(Settings, vsp_environment: 'production') do
            post '/ivc_champva/v1/forms', params: data
            expect(IvcChampva::VesDataFormatter).not_to have_received(:format_for_request)
            expect(ves_client).not_to have_received(:submit_1010d)
          end
        end
      end

      context 'when environment is not production' do
        it 'does VES processing only for form 10-10D' do
          with_settings(Settings, vsp_environment: 'staging') do
            controller = IvcChampva::V1::UploadsController.new
            allow(controller).to receive_messages(call_handle_file_uploads: [[200], nil],
                                                  call_upload_form: [[200], nil],
                                                  get_file_paths_and_metadata: [[['path'], {}], {}],
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
        end

        it 'returns an error and does proceed when format_for_request throws an error' do
          with_settings(Settings, vsp_environment: 'staging') do
            if data['form_number'] == '10-10D'
              allow(IvcChampva::VesDataFormatter).to receive(:format_for_request).and_raise(StandardError.new('oh no'))
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
        end

        it 'returns an error and does not proceed when format_for_request returns nil' do
          with_settings(Settings, vsp_environment: 'staging') do
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
        end

        it 'returns an error and does not proceed when handle_file_uploads fails' do
          with_settings(Settings, vsp_environment: 'staging') do
            if data['form_number'] == '10-10D'
              controller = IvcChampva::V1::UploadsController.new
              allow(controller).to receive_messages(call_upload_form: [[400], 'oh no'],
                                                    get_file_paths_and_metadata: [[['path'], {}], {}],
                                                    params: ActionController::Parameters.new(data))
              allow(controller).to receive(:render)

              controller.send(:submit)

              expect(ves_client).not_to have_received(:submit_1010d)
              expect(controller).to have_received(:render)
                .with({ json: { error_message: 'oh no' }, status: 400 })
            end
          end
        end

        it 'returns ok when submitting to VES results in an error' do
          with_settings(Settings, vsp_environment: 'staging') do
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

  describe 'stored ves data is encrypted' do
    it 'ves_request_data is encrypted' do
      # This is the only part of the test we actually need
      expect(IvcChampvaForm.new).to encrypt_attr(:ves_request_data)
    end
  end

  describe '#submit_supporting_documents' do
    let(:file) { fixture_file_upload('doctors-note.gif') }

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

  describe '#get_form_id' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    it 'returns the correct form ID for a valid form number' do
      allow(controller).to receive(:params).and_return({ form_number: '10-10D' })
      form_id = controller.send(:get_form_id)

      expect(form_id).to eq('vha_10_10d')
    end

    it 'raises an error for a missing form number' do
      allow(controller).to receive(:params).and_return({})
      expect { controller.send(:get_form_id) }.to raise_error('Missing/malformed form_number in params')
    end
  end

  describe '#get_attachment_ids_and_form' do
    let(:controller) { IvcChampva::V1::UploadsController.new }
    let(:mock_user) { double('User', loa: { current: 3 }) }

    before do
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
          let(:metadata) { { 'attachment_ids' => %w[id1 id2] } }
          let(:file_uploader) { instance_double(IvcChampva::FileUploader) }
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

              # TODO: should this be nil, or 400/'Upload failed'?
              expect(statuses).to be_nil
              expect(error_message).to be_nil
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
          let(:metadata) { { 'attachment_ids' => %w[id1 id2] } }
          let(:file_uploader) { instance_double(IvcChampva::FileUploader) }
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

              # TODO: should this be nil, or 400/'Upload failed'?
              expect(statuses).to be_nil
              expect(error_message).to be_nil
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
end
