# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'fake_vbms.rb')

RSpec.describe Debts::LetterDownloader do
  subject { described_class.new(file_number) }

  let(:file_number) { '796330625' }
  let(:vbms_client) { FakeVbms.new }
  let(:request_double) do
    request_double = double
    expect("VBMS::Requests::#{request_name}".constantize).to receive(:new).with(request_args).and_return(request_double)

    request_double
  end

  before do
    allow(VBMS::Client).to receive(:from_env_vars).and_return(vbms_client)
  end

  def get_vbms_fixture(path)
    get_fixture("vbms/#{path}").map { |r| OpenStruct.new(r) }
  end

  describe '#get_letter' do
    let(:request_name) { 'GetDocumentContent' }
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:request_args) { document_id }
    let(:content) { File.read('spec/fixtures/pdf_fill/extras.pdf') }

    before do
      expect(vbms_client).to receive(:send_request).with(
        request_double
      ).and_return(
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

  describe '#list_letters' do
    let(:request_name) { 'FindDocumentVersionReference' }
    let(:request_args) { file_number }

    before do
      expect(vbms_client).to receive(:send_request).with(
        request_double
      ).and_return(get_vbms_fixture('find_document_version_reference'))
    end

    it 'gets letter ids and descriptions' do
      expect(subject.list_letters).to eq(
        [
          {
            document_id: '{93631483-E9F9-44AA-BB55-3552376400D8}',
            doc_type: '1215',
            type_description: 'DMC - Debt Increase Letter',
            received_at: '2020-05-28'
          },
          {
            document_id: '{358692DF-7AE5-43A7-99AB-D5F4F98E3F3A}',
            doc_type: '1215',
            type_description: 'DMC - Debt Increase Letter',
            received_at: '2020-05-28'
          }
        ]
      )
    end
  end
end
