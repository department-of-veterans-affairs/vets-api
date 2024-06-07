# frozen_string_literal: true

require 'rails_helper'
require 'bb/generate_report_request_form.rb'

describe MyHealth::V1::EligibleDataClassesSerializer do
  let(:eligible_data_classes) { build_list(:eligible_data_class, 3) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(eligible_data_classes, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :data_classes' do
    expect(rendered_attributes[:data_classes]).to eq eligible_data_classes.map(&:name)
  end
end
