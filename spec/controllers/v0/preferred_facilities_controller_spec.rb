# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::PreferredFacilitiesController, type: :controller do
  let(:user) { create(:user, :loa3, :accountable) }

  before do
    sign_in_as(user)
  end

  let!(:preferred_facility1) { create(:preferred_facility) }
  let!(:preferred_facility2) { create(:preferred_facility, user: user) }
  let!(:preferred_facility3) do
    create(:preferred_facility, facility_code: '688', user: user)
  end

  describe '#index' do
    it 'lists a users preferred facilities' do
      get(:index)

      expect(
        JSON.parse(response.body)['data'].map do |preferred_facility_data|
          preferred_facility_data['attributes']
        end
      ).to eq(
        [
          { 'facility_code' => '983' },
          { 'facility_code' => '688' },
        ]
      )
    end
  end

  describe '#destroy' do
    context 'with another users preferred facility' do
      it 'doesnt destroy the preferred facility' do
        id = preferred_facility1.id
        delete(:destroy, params: { id: id })

        expect(response.ok?).to eq(false)
        expect(PreferredFacility.exists?(id)).to eq(true)
      end
    end

    it 'destroys a users preferred facility' do
      id = preferred_facility2.id
      delete(:destroy, params: { id: id })

      expect(response.ok?).to eq(true)
      expect(PreferredFacility.exists?(id)).to eq(false)
    end
  end

  describe '#create' do
    let(:facility_code) { '405HK' }

    before do
      allow_any_instance_of(User).to receive(:va_treatment_facility_ids).and_return(
        %w[983 688 405HK]
      )
    end

    subject do
      post(
        :create,
        params: {
          preferred_facility: {
            facility_code: facility_code
          }
        }
      )
    end

    it 'creates a preferred facility' do
      subject

      expect(response.ok?).to eq(true)

      preferred_facility = PreferredFacility.last
      expect(preferred_facility.facility_code).to eq(facility_code)
      expect(preferred_facility.account).to eq(user.account)
    end

    context 'with invalid params' do
      let(:facility_code) { 'foo' }

      it 'returns a validation error' do
        subject

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
          "facility-code - must be included in user's va treatment facilities list"
        )
      end
    end
  end
end
