# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersonalInformationLog do
  let(:pi_log) do
    PersonalInformationLog.create(error_class: 'my_type', data: { cool: 'stuff' })
  end

  describe '#decoded_data' do
    it 'simplies return data when not a logged request/response' do
      expect(pi_log.decoded_data).to eq(pi_log.data)
    end

    it 'returns decoded request/response values when present' do
      pi_log.data.merge!('request_body' => Base64.encode64('special request'),
                         'response_body' => Base64.encode64('nominal response'))
      expect(pi_log.data['request_body']).not_to eq('special request')
      expect(pi_log.decoded_data['request_body']).to eq('special request')

      expect(pi_log.data['response_body']).not_to eq('nominal response')
      expect(pi_log.decoded_data['response_body']).to eq('nominal response')
    end
  end
end
