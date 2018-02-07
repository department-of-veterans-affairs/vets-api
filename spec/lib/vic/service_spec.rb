# frozen_string_literal: true

require 'rails_helper'

describe VIC::Service do
  describe '#get_oauth_token' do
    it 'should get the access token from the request', run_at: '2018-02-06 21:51:48 -0500' do
      service = described_class.new
      oauth_params = get_fixture('vic/oauth_params').symbolize_keys
      return_val = OpenStruct.new(body: { 'access_token' => 'token' })
      expect(service).to receive(:request).with(:post, '', oauth_params).and_return(return_val)

      expect(service.get_oauth_token).to eq('token')
    end
  end
end
