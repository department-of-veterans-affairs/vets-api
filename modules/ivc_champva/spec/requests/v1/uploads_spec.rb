# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Forms uploader', type: :request do
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
    shared_examples 'returns the correct attachment IDs and form object' do |form_number, form_class|
    let(:parsed_form_data) do
      {
        'form_number' => form_number,
        'supporting_docs' => [
          { 'attachment_id' => 'doc1' },
          { 'attachment_id' => 'doc2' }
        ]
      }
    end
# rubocop:disable Style/HashSyntax
    it 'returns the correct attachment IDs and form object' do
      post ivc_champva_v1_forms_path, params: { form_number: form_number }
      attachment_ids, form = controller.send(:get_attachment_ids_and_form, parsed_form_data)
      expect(attachment_ids).to include(form_class.new({}).form_id)
      expect(attachment_ids).to include('doc1')
      expect(attachment_ids).to include('doc2')
      expect(form).to be_an_instance_of(form_class)
      expect(form.form_id).to eq(form_class.new({}).form_id)
      expect(form.data['form_number']).to eq(form_number)
    end

    context 'when supporting_docs is empty' do
      let(:parsed_form_data) { { 'form_number' => form_number } }

      it 'returns only the form ID in attachment_ids' do
        post ivc_champva_v1_forms_path, params: { form_number: form_number }
        attachment_ids, _form = controller.send(:get_attachment_ids_and_form, parsed_form_data)
        expect(attachment_ids).to eq([form_class.new({}).form_id])
      end
    end
  end
# rubocop:enable Style/HashSyntax

  form_numbers = [
    ['10-10D', IvcChampva::VHA1010d],
    ['10-7959C', IvcChampva::VHA107959c]
  ]

  form_numbers.each do |form_number, form_class|
    context "when form_number is #{form_number}" do
        include_examples 'returns the correct attachment IDs and form object', form_number, form_class
      end
    end
  end
end
