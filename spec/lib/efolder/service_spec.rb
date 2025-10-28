# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'fake_vbms.rb')
require 'efolder/service'

RSpec.describe Efolder::Service do
  subject { described_class.new(user) }

  let(:file_number) { '796043735' }
  let(:user) { build(:user, :loa3, ssn: file_number) }
  let(:vbms_client) { FakeVBMS.new }
  let(:tsa_letter_data) do
    OpenStruct.new(
      document_id: '{tsa-letter-document-id}',
      series_id: '{tsa-letter-series-id}',
      version: '1',
      type_description: 'Correspondence',
      type_id: '34',
      doc_type: '34',
      subject: 'VETS Safe Travel Outreach Letter',
      received_at: '2020-05-28',
      source: 'Virtual VA',
      mime_type: 'application/pdf',
      alt_doc_types: nil,
      restricted: false,
      upload_date: '2020-06-03'
    )
  end

  def stub_vbms_client_request(request_name, args, return_val)
    request_double = double
    expect("VBMS::Requests::#{request_name}".constantize).to receive(:new).with(args).and_return(request_double)

    expect(vbms_client).to receive(:send_request).with(
      request_double
    ).and_return(
      return_val
    )
  end

  def get_vbms_fixture(path)
    get_fixture("vbms/#{path}").map { |r| OpenStruct.new(r) }
  end

  before do
    allow(VBMS::Client).to receive(:from_env_vars).and_return(vbms_client)
  end

  describe '#get_document' do
    before do
      stub_vbms_client_request(
        'FindDocumentVersionReference',
        file_number,
        get_vbms_fixture('find_document_version_reference')
      )
    end

    context 'with a document in the users folder' do
      let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
      let(:content) { File.read('spec/fixtures/pdf_fill/extras.pdf') }

      before do
        stub_vbms_client_request(
          'GetDocumentContent',
          document_id,
          OpenStruct.new(
            document_id:,
            content:
          )
        )
      end

      it 'downloads a document' do
        VCR.use_cassette('bgs/uploaded_document_service/uploaded_document_data') do
          VCR.use_cassette('bgs/people_service/person_data') do
            expect(subject.get_document(document_id)).to eq(content)
          end
        end
      end
    end

    context 'with a document not in the users folder' do
      let(:document_id) { '{abc}' }

      it 'raises an unauthorized error' do
        VCR.use_cassette('bgs/uploaded_document_service/uploaded_document_data') do
          VCR.use_cassette('bgs/people_service/person_data') do
            expect { subject.get_document(document_id) }.to raise_error(Common::Exceptions::Unauthorized)
          end
        end
      end
    end
  end

  describe '#list_documents' do
    before do
      stub_vbms_client_request(
        'FindDocumentVersionReference',
        file_number,
        get_vbms_fixture('find_document_version_reference')
      )
    end

    it 'lists document ids and descriptions' do
      VCR.use_cassette('bgs/uploaded_document_service/uploaded_document_data') do
        VCR.use_cassette('bgs/people_service/person_data') do
          expect(subject.list_documents.to_json).to eq(
            get_fixture('vbms/list_documents').to_json
          )
        end
      end
    end

    it 'returns an empty array if UploadedDocumentService raises an error' do
      allow_any_instance_of(BGS::Services).to receive(:uploaded_document).and_raise(Common::Exceptions::BadGateway)
      VCR.use_cassette('bgs/people_service/person_data') do
        expect(subject.list_documents).to be_empty
      end
    end

    it 'uses SSN if BGS File Number is not found' do
      VCR.use_cassette('bgs/uploaded_document_service/uploaded_document_data') do
        expect(subject.list_documents.to_json).to eq(get_fixture('vbms/list_documents').to_json)
      end
    end
  end

  describe '#list_tsa_letters' do
    before do
      stub_vbms_client_request(
        'FindDocumentVersionReference',
        file_number,
        get_fixture('vbms/find_document_version_reference').map { |r| OpenStruct.new(r) }.push(tsa_letter_data)
      )
    end

    it 'returns requested document' do
      VCR.use_cassette('vbms/list_documents') do
        expect(subject.list_tsa_letters).to eq([tsa_letter_data])
      end
    end
  end

  describe '#get_tsa_letter' do
    before do
      stub_vbms_client_request(
        'FindDocumentVersionReference',
        file_number,
        get_fixture('vbms/find_document_version_reference').map { |r| OpenStruct.new(r) }.push(tsa_letter_data)
      )
    end

    context 'when TSA letter is found' do
      let(:document_id) { '{tsa-letter-document-id}' }
      let(:content) { File.read('spec/fixtures/pdf_fill/extras.pdf') }

      before do
        stub_vbms_client_request(
          'GetDocumentContent',
          document_id,
          OpenStruct.new(
            document_id:,
            content:
          )
        )
      end

      it 'sends binary file content' do
        VCR.use_cassette('bgs/uploaded_document_service/uploaded_document_data') do
          VCR.use_cassette('bgs/people_service/person_data') do
            expect(subject.get_tsa_letter(document_id)).to eq(content)
          end
        end
      end
    end

    context 'when letter is found but is not a TSA letter' do
      let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }

      it 'raises a not found error' do
        VCR.use_cassette('bgs/people_service/person_data') do
          expect { subject.get_tsa_letter(document_id) }.to raise_error(Common::Exceptions::RecordNotFound)
        end
      end
    end

    context 'when the document is not found' do
      let(:document_id) { '{abc}' }

      it 'raises a not found error' do
        VCR.use_cassette('bgs/people_service/person_data') do
          expect { subject.get_tsa_letter(document_id) }.to raise_error(Common::Exceptions::RecordNotFound)
        end
      end
    end
  end
end
