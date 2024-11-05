# frozen_string_literal: true

require 'rails_helper'
require 'bb/generate_report_request_form'

describe EligibleDataClassesSerializer, type: :serializer do
  subject { serialize(eligible_data_classes, { serializer_class: described_class, is_collection: false }) }

  let(:eligible_data_classes) { build_list(:eligible_data_class, 3) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['data']).to be_blank
  end

  it 'includes :type' do
    expect(data['type']).to eq 'eligible_data_classes'
  end

  it 'includes :data_classes' do
    expect(attributes['data_classes']).to eq eligible_data_classes.map(&:name)
  end
end
