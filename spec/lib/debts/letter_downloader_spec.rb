# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'fake_vbms.rb')

RSpec.describe Debts::LetterDownloader do
  subject { described_class.new(file_number) }

  let(:file_number) { '796330625' }
  let(:vbms_client) { FakeVbms.new }

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

    stub_vbms_client_request(
      'FindDocumentVersionReference',
      file_number,
      get_vbms_fixture('find_document_version_reference')
    )
  end

  describe '#get_letter' do
    context 'with a document in the users folder' do
      let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
      let(:content) { File.read('spec/fixtures/pdf_fill/extras.pdf') }

      before do
        stub_vbms_client_request(
          'GetDocumentContent',
          document_id,
          OpenStruct.new(
            document_id: document_id,
            content: content
          )
        )
      end

      it 'downloads a debt letter' do
        expect(subject.get_letter(document_id)).to eq(content)
      end
    end

    context 'with a document not in the users folder' do
      let(:document_id) { '{abc}' }

      it 'raises an unauthorized error' do
        expect { subject.get_letter(document_id) }.to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end

  describe '#list_letters' do
    it 'gets letter ids and descriptions' do
      expect(subject.list_letters.to_json).to eq(
        get_fixture('vbms/list_letters').to_json
      )
    end
  end
end
