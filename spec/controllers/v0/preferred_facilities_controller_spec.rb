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
end
