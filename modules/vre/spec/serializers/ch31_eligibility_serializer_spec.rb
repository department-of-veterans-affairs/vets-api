# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::Ch31EligibilitySerializer, type: :serializer do
  subject { serialize(response, serializer_class: described_class) }

  let(:json) { File.read('modules/vre/spec/fixtures/ch31_eligibility.json') }
  let(:body) { JSON.parse(json).deep_transform_keys!(&:underscore) }
  let(:raw_response) { instance_double(Faraday::Env, body:) }
  let(:response) { VRE::Ch31Eligibility::Response.new(200, raw_response) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :veteran_profile' do
    expect(attributes['veteran_profile']).to eq(body['veteran_profile'])
  end

  it 'includes :disability_rating' do
    expect(attributes['disability_rating']).to eq(body['disability_rating'])
  end

  it 'includes :irnd_date' do
    expect(attributes['irnd_date']).to eq(body['irnd_date'])
  end

  it 'includes :eligibility_termination_date' do
    expect(attributes['eligibility_termination_date']).to eq(body['eligibility_termination_date'])
  end

  it 'includes :entitlement_details' do
    expect(attributes['entitlement_details']).to eq(body['entitlement_details'])
  end

  it 'includes :res_case_id' do
    expect(attributes['res_case_id']).to eq(body['res_case_id'])
  end

  it 'includes :qualifying_military_service_status' do
    expect(attributes['qualifying_military_service_status']).to eq(body['qualifying_military_service_status'])
  end

  it 'includes :character_of_discharge_status' do
    expect(attributes['character_of_discharge_status']).to eq(body['character_of_discharge_status'])
  end

  it 'includes :disability_rating_status' do
    expect(attributes['disability_rating_status']).to eq(body['disability_rating_status'])
  end

  it 'includes :irnd_status' do
    expect(attributes['irnd_status']).to eq(body['irnd_status'])
  end

  it 'includes :eligibility_termination_date_status' do
    expect(attributes['eligibility_termination_date_status']).to eq(body['eligibility_termination_date_status'])
  end

  it 'includes :res_eligibiltiy_recommendation' do
    expect(attributes['res_eligibiltiy_recommendation']).to eq(body['res_eligibiltiy_recommendation'])
  end
end
