# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/demographics/demographic_response'

RSpec.describe PersonalInformationSerializer, type: :serializer do
  let(:demographics) { get_demographics }
  let(:response) { serialize(demographics, serializer_class: described_class) }
  let(:attributes) { JSON.parse(response)['data']['attributes'] }

  context 'when gender is nil' do
    it 'returns nil for gender' do
      expect(attributes['gender']).to be_nil
    end
  end

  context 'when birth_date is nil' do
    it 'returns nil for birth_date' do
      expect(attributes['birth_date']).to be_nil
    end
  end

  private

  def get_demographics(attributes = {})
    VAProfile::Demographics::DemographicResponse.from(
      status: 200,
      body: nil,
      id: '12345',
      type: 'mvi_models_mvi_profiles',
      gender: attributes[:gender],
      birth_date: attributes[:birth_date]
    )
  end
end
