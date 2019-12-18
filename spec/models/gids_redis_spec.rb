# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'
require 'gids_redis/GIDS'

describe GIDSRedis do
  let(:rest_call) { :get_institution_details }
  let(:scrubbed_params) { {} }
  let(:service) { GIDSRedis.new }
  let(:status) { 200 }
  let(:body) { {} }
  let(:gi_response) do
    GI::Responses::GIDSResponse.new(status: status, body: body)
  end

  it 'gi_response' do
    allow_any_instance_of(GI::Client).to receive(:get_institution_details).and_return(gi_response)

    service.rest_call = rest_call
    service.scrubbed_params = scrubbed_params
    expect(service.gi_response).to eq(gi_response)
  end

  it 'method_missing' do
    allow_any_instance_of(GI::Client).to receive(:get_institution_details).and_return(gi_response)

    expect(service.get_institution_details(scrubbed_params)).to eq(gi_response.body)
  end
end
