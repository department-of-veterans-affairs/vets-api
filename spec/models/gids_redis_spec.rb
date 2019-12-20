# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe GIDSRedis do
  let(:scrubbed_params) { {} }
  let(:service) { GIDSRedis.new }
  let(:body) { {} }
  let(:gi_response) do
    GI::Responses::GIDSResponse.new(status: 200, body: body)
  end

  describe 'method_missing' do
    it 'returns response body' do
      allow_any_instance_of(GI::Client).to receive(:get_institution_details).and_return(gi_response)

      expect(service.get_institution_details(scrubbed_params)).to eq(gi_response.body)
    end
  end
end
