# frozen_string_literal: true

require 'rails_helper'
require 'dgi/exclusion_period/response'

describe ExclusionPeriodSerializer do
  let(:exclusion_period) do
    response = double('response', status: 201, body: { 'exclusion_periods' => %w[ROTC NoPayDate] })
    MebApi::DGI::ExclusionPeriod::Response.new(response)
  end

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_exclusion_period_responses',
        attributes: {
          exclusion_periods: %w[ROTC NoPayDate]
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(exclusion_period, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :exclusion_periods' do
    expect(rendered_attributes[:exclusion_periods]).to eq expected_response[:data][:attributes][:exclusion_periods]
  end
end
