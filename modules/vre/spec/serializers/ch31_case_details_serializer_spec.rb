# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::Ch31CaseDetailsSerializer, type: :serializer do
  subject { serialize(response, serializer_class: described_class) }

  let(:json) { File.read('modules/vre/spec/fixtures/ch31_case_details.json') }
  let(:body) { JSON.parse(json).deep_transform_keys!(&:underscore) }
  let(:raw_response) { instance_double(Faraday::Env, body:) }
  let(:response) { VRE::Ch31CaseDetails::Response.new(200, raw_response) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :res_case_id' do
    expect(attributes['res_case_id']).to eq(body['res_case_id'])
  end

  it 'includes :is_transferred_to_cwnrs' do
    expect(attributes['is_transferred_to_cwnrs']).to eq(body['is_transferred_to_cwnrs'])
  end

  it 'includes :orientation_appointment_details' do
    expect(attributes['orientation_appointment_details']).to eq(body['orientation_appointment_details'])
  end

  it 'includes :external_status' do
    expect(attributes['external_status']).to eq(body['external_status'])
  end
end
