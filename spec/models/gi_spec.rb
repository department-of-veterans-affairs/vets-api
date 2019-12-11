# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe Gi do
  let(:rest_call) { :get_institution_details }
  let(:scrubbed_params) { {} }
  let(:gi) { Gi.for_controller(rest_call, scrubbed_params) }
  let(:status) { 200 }
  let(:body) { {} }
  let(:gi_response) do
    GI::Responses::GiResponse.new(status: status, body: body)
  end

  describe 'for_controller' do
    it '.rest_call' do
      expect(gi.rest_call).to eq(rest_call)
    end

    it '.scrubbed_params' do
      expect(gi.scrubbed_params).to eq(scrubbed_params)
    end
  end

  it 'body' do
    allow_any_instance_of(GI::Client).to receive(:get_institution_details).and_return(gi_response)

    expect(gi.body).to eq(body)
  end

  it 'status' do
    allow_any_instance_of(GI::Client).to receive(:get_institution_details).and_return(gi_response)

    expect(gi.status).to eq(status)
  end
end
