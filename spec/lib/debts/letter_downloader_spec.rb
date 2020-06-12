# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/modules/claims_api/spec/support/fake_vbms"

RSpec.describe Debts::LetterDownloader do
  let(:letter_downloader) { described_class.new('796330625') }

  before do
    vbms_client = FakeVbms.new
    allow(VBMS::Client).to receive(:from_env_vars).and_return(vbms_client)
  end

  describe '#list_letters' do
    it 'should get letter ids and descriptions' do
      VCR.use_cassette('vbms/find_document_version_reference') do
        letter_downloader.list_letters
      end
    end
  end
end
