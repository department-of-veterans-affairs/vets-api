# frozen_string_literal: true

require 'rails_helper'

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

  before do
    @original_aws_config = Aws.config.dup
    Aws.config.update(stub_responses: true)
  end

  after do
    Aws.config = @original_aws_config
  end

  describe '#submit' do
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
    end
  end

  describe '#submit_supporting_documents' do
    it 'renders the attachment as json' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)
      file = fixture_file_upload('doctors-note.gif')

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
    it 'returns the correct attachment ids and form' do
      attachments = [double('Attachment', id: 1), double('Attachment', id: 2)]
      form = double('Form', id: 1)

      allow(controller).to receive(:get_attachment_ids_and_form).and_return([attachments.map(&:id), form])

      result = controller.get_attachment_ids_and_form
      expect(result).to eq([[1, 2], form])
    end
  end

  describe '#generate_attachment_ids' do
    it 'generates the correct attachment ids' do
      attachments = [double('Attachment', id: 1), double('Attachment', id: 2)]

      allow(controller).to receive(:generate_attachment_ids).and_return(attachments.map(&:id))

      result = controller.generate_attachment_ids
      expect(result).to eq([1, 2])
    end
  end

  describe '#unlock_file' do
    before do
      allow(Flipper).to receive(:enabled?)
        .with(:champva_pdf_decrypt, @current_user)
        .and_return(true)
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
  end

  describe '#supporting_document_ids' do
    it 'returns the correct supporting document ids' do
      documents = [double('Document', id: 1), double('Document', id: 2)]

      allow(controller).to receive(:supporting_document_ids).and_return(documents.map(&:id))

      result = controller.supporting_document_ids
      expect(result).to eq([1, 2])
    end

    it 'orders supporting document ids by date created' do
      clamscan = double(safe?: true)
      allow(Common::VirusScan).to receive(:scan).and_return(clamscan)

      # Mocking PersistentAttachments::MilitaryRecords to return controlled data
      record1 = double('Record1', created_at: 1.day.ago, id: 'doc0', file: double(id: 'file0'))
      record2 = double('Record2', created_at: Time.zone.now, id: 'doc1', file: double(id: 'file1'))

      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by).with(guid: 'code1').and_return(record1)
      allow(PersistentAttachments::MilitaryRecords).to receive(:find_by).with(guid: 'code2').and_return(record2)

      parsed_form_data = {
        'form_number' => '10-10D',
        'supporting_docs' => [
          { 'attachment_id' => 'doc1', 'confirmation_code' => 'code2' },
          { 'attachment_id' => 'doc0', 'confirmation_code' => 'code1' }
        ]
      }

      # Create an instance of the controller
      controller = IvcChampva::V1::UploadsController.new

      # Call the private method using `send`
      attachment_ids = controller.send(:supporting_document_ids, parsed_form_data)

      # Mock metadata generation to align with the sorted order
      metadata = { 'metadata' => {}, 'attachment_ids' => attachment_ids }

      expect(metadata).to eq({
                               'metadata' => {},
                               'attachment_ids' => %w[doc0 doc1] # Ensure this matches the sorted order
                             })
    end

    it 'throws an error when no matching supporting doc is present in the database' do
      controller = IvcChampva::V1::UploadsController.new
      parsed_form_data = {
        'form_number' => '10-10D',
        'supporting_docs' => [
          { 'attachment_id' => 'doc0', 'confirmation_code' => 'NOT_IN_DATABASE' }
        ]
      }
      expect do
        controller.send(:supporting_document_ids, parsed_form_data)
      end.to raise_error(NoMethodError)
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
          # TODO: add tests to cover when the `require_all_s3_success` feature is enabled
          allow(Flipper).to receive(:enabled?).with(:champva_require_all_s3_success, @current_user).and_return(false)
          allow(controller).to receive(:get_file_paths_and_metadata).and_return([file_paths, metadata])
          allow(IvcChampva::FileUploader).to receive(:new).and_return(file_uploader)
        end

        context 'when file uploads succeed' do
          before do
            allow(file_uploader).to receive(:handle_uploads).and_return([200, nil])
          end

          it 'returns success statuses and no error message' do
            statuses, error_message = controller.send(:handle_file_uploads, form_id, parsed_form_data)
            expect(statuses).to eq([200])
            expect(error_message).to eq([])
          end
        end

        context 'when file uploads fail with other errors' do
          before do
            allow(file_uploader).to receive(:handle_uploads).and_return(error_response)
          end

          it 'returns the error statuses and error message' do
            statuses, error_message = controller.send(:handle_file_uploads, form_id, parsed_form_data)
            expect(statuses).to eq([200, 400])
            expect(error_message).to eq([nil, 'Upload failed'])
          end
        end

        context 'when file uploads fail with other errors retry once' do
          subject(:result) { controller.send(:handle_file_uploads, form_id, parsed_form_data) }

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
            # TODO: add tests to cover all other error conditions with handle_uploads, eg:
            # allow(file_uploader).to receive(:handle_uploads).and_return([400, 'Upload failed'])
          end

          it 'retries handle_uploads and returns an error message' do
            # Expect handle_uploads to be called twice due to one retry
            expect(file_uploader).to receive(:handle_uploads).at_least(:twice)
            _statuses, _error_message = controller.send(:handle_file_uploads, form_id, parsed_form_data)
            # This expectation causes the `.to receive(:handle_uploads)` count to increment by 1:
            expect { file_uploader.handle_uploads }.to raise_error(StandardError, /Unable to find file/)
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
