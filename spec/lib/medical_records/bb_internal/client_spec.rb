# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/bb_internal/client'
require 'stringio'

describe BBInternal::Client do
  before(:all) do
    VCR.use_cassette 'mr_client/bb_internal/session', record: :new_episodes do
      VCR.use_cassette 'mr_client/bb_internal/get_patient', record: :new_episodes do
        @client ||= begin
          client = BBInternal::Client.new(session: { user_id: '15176497' })
          client.authenticate
          client
        end
      end
    end
  end

  let(:client) { @client }

  describe 'get_radiology' do
    it 'gets the radiology records' do
      VCR.use_cassette 'mr_client/bb_internal/get_radiology' do
        radiology_results = client.list_radiology
        expect(radiology_results).to be_an(Array)
        result = radiology_results[0]
        expect(result).to be_a(Hash)
        expect(result).to have_key('procedureName')
      end
    end
  end
end
