# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/bb_internal/client'
require 'stringio'

describe BBInternal::Client do
  before(:all) do
    @client ||= begin
      client = BBInternal::Client.new(session: { user_id: '11383893' })
      client.authenticate
      client
    end
  end

  let(:client) { @client }

  describe 'Getting radiology records' do
    it 'gets the records' do
      VCR.use_cassette 'mr_client/bb_internal/get_radiology' do
        radiology_results = client.get_radiology
        expect(radiology_results).to be_an(Array)
        result = radiology_results[0]
        expect(result).to be_a(Hash)
        expect(result).to have_key('procedureName')
      end
    end
  end
end
