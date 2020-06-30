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
    before do
      # rubocop:disable RSpec/SubjectStub
      expect(subject).to receive(:list_letters).and_return(
        get_fixture('vbms/list_letters').map!(&:symbolize_keys)
      )
      # rubocop:enable RSpec/SubjectStub
    end

    context 'with a document in the users folder' do
      let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
      let(:request_name) { 'GetDocumentContent' }
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

    context 'with a document not in the users folder' do
      let(:document_id) { '{abc}' }

      it 'raises an unauthorized error' do
        expect { subject.get_letter(document_id) }.to raise_error(Common::Exceptions::Unauthorized)
      end
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
      expect(subject.list_letters.to_json).to eq(
        get_fixture('vbms/list_letters').to_json
      )
    end
  end
end
