# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/modules/claims_api/spec/support/fake_vbms"

RSpec.describe Debts::LetterDownloader do
  let(:file_number) { '796330625' }
  let(:letter_downloader) { described_class.new(file_number) }
  let(:vbms_client) { FakeVbms.new }
  let(:request_double) do
    request_double = double
    expect("VBMS::Requests::#{request_name}".constantize).to receive(:new).with(file_number).and_return(request_double)

    request_double
  end

  before do
    allow(VBMS::Client).to receive(:from_env_vars).and_return(vbms_client)
  end

  def get_vbms_fixture(path)
    get_fixture("vbms/#{path}").map { |r| OpenStruct.new(r) }
  end

  describe '#list_letters' do
    let(:request_name) { 'FindDocumentVersionReference' }

    before do
      expect(vbms_client).to receive(:send_request).with(
        request_double
      ).and_return(get_vbms_fixture('find_document_version_reference'))
    end

    it 'should get letter ids and descriptions' do
      letter_downloader.list_letters
    end
  end
end
