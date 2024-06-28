# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Forms uploader', type: :request do
  # forms_numbers_and_classes is a hash that maps form numbers if they have attachments
  form_numbers_and_classes = {
    '10-10D' => IvcChampva::VHA1010d,
    '10-7959C' => IvcChampva::VHA107959c,
    '10-7959F-2' => IvcChampva::VHA107959f2
  }

  forms = [
    'vha_10_10d.json',
    'vha_10_7959f_1.json',
    'vha_10_7959f_2.json',
    'vha_10_7959c.json'
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
        allow(IvcChampvaForm).to receive(:first).and_return(mock_form)
        allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(true)

        post '/ivc_champva/v1/forms', params: data

        record = IvcChampvaForm.first

        expect(record.first_name).to eq('Veteran')
        expect(record.last_name).to eq('Surname')
        expect(record.form_uuid).to be_present

        expect(response).to have_http_status(:ok)
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
      expect { controller.send(:get_form_id) }.to raise_error('missing form_number in params')
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

  describe '#supporting_document_ids' do
    it 'returns the correct supporting document ids' do
      documents = [double('Document', id: 1), double('Document', id: 2)]

      allow(controller).to receive(:supporting_document_ids).and_return(documents.map(&:id))

      result = controller.supporting_document_ids
      expect(result).to eq([1, 2])
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
          allow(IvcChampva::MetadataValidator).to receive(:validate).and_return('metadata')
          allow_any_instance_of(form_class).to receive(:handle_attachments).and_return(['file_path'])

          file_paths, metadata, attachment_ids = controller.send(:get_file_paths_and_metadata, parsed_form_data)

          expect(file_paths).to eq(['file_path'])
          expect(metadata).to eq('metadata')
          expect(attachment_ids).to eq(%w[doc1 doc2])
        end
      end
    end
  end

  describe '#build_json' do
    let(:controller) { IvcChampva::V1::UploadsController.new }

    context 'when all status codes are 200' do
      it 'returns a status of 200' do
        expect(controller.send(:build_json, [200, 200], 'Error')).to eq({ json: {}, status: 200 })
      end
    end

    context 'when all status codes are 400' do
      it 'returns a status of 400 and an error message' do
        expect(controller.send(:build_json, [400, 400], nil)).to eq({ json:
        { error_message: 'An unknown error occurred while uploading some documents.' }, status: 400 })
      end
    end

    context 'when status codes include a 400' do
      it 'returns a status of 400' do
        expect(controller.send(:build_json, [200, 400], nil)).to eq({ json:
        { error_message: 'An unknown error occurred while uploading some documents.' }, status: 400 })
      end
    end

    context 'when status codes are do not include 200 or 400' do
      it 'returns a status of 500' do
        expect(controller.send(:build_json, [300, 500], 'Error')).to eq({ json:
        { error_message: 'An unknown error occurred while uploading document(s).' }, status: 500 })
      end
    end
  end
end
