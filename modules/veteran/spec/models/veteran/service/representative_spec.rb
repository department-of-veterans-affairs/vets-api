# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Representative, type: :model do
  let(:identity) { FactoryBot.create(:user_identity) }

  describe 'individual record' do
    it 'is valid with valid attributes' do
      expect(Veteran::Service::Representative.new(representative_id: '12345', poa_codes: ['000'])).to be_valid
    end

    it 'is not valid without a poa' do
      representative = Veteran::Service::Representative.new(representative_id: '67890', poa_codes: nil)
      expect(representative).not_to be_valid
    end
  end

  def basic_attributes
    {
      representative_id: SecureRandom.hex(8),
      first_name: identity.first_name,
      last_name: identity.last_name
    }
  end

  describe 'finding by identity' do
    let(:rep) do
      FactoryBot.create(:representative,
                        basic_attributes.merge!(ssn: identity.ssn, dob: identity.birth_date))
    end

    before do
      identity
      rep
    end

    describe 'finding by all fields' do
      it 'finds a user by name, ssn, and dob' do
        expect(Veteran::Service::Representative.for_user(
          first_name: identity.first_name,
          last_name: identity.last_name,
          dob: identity.birth_date,
          ssn: identity.ssn
        ).id).to eq(rep.id)
      end

      it 'finds right user when 2 with the same name exist' do
        FactoryBot.create(:representative,
                          basic_attributes.merge!(ssn: '123-45-6789', dob: '1929-10-01'))
        expect(Veteran::Service::Representative.for_user(
          first_name: identity.first_name,
          last_name: identity.last_name,
          dob: identity.birth_date,
          ssn: identity.ssn
        ).id).to eq(rep.id)
      end
    end

    describe 'finding by the name only' do
      it 'finds a user by name fields' do
        rep = FactoryBot.create(:representative, first_name: 'Bob', last_name: 'Smith')
        identity = FactoryBot.create(:user_identity, first_name: rep.first_name, last_name: rep.last_name)
        Veteran::Service::Representative.for_user(
          first_name: identity.first_name,
          last_name: identity.last_name
        )
        expect(Veteran::Service::Representative.for_user(
          first_name: identity.first_name,
          last_name: identity.last_name
        ).id).to eq(rep.id)
      end
    end
  end

  describe '.find_within_max_distance' do
    before do
      create(:representative, representative_id: '456', long: -77.050552, lat: 38.820450,
                              location: 'POINT(-77.050552 38.820450)') # ~6 miles from Washington, D.C.

      create(:representative, representative_id: '789', long: -76.609383, lat: 39.299236,
                              location: 'POINT(-76.609383 39.299236)') # ~35 miles from Washington, D.C.

      create(:representative, representative_id: '123', long: -77.466316, lat: 38.309875,
                              location: 'POINT(-77.466316 38.309875)') # ~47 miles from Washington, D.C.

      create(:representative, representative_id: '246', long: -76.3483, lat: 39.5359,
                              location: 'POINT(-76.3483 39.5359)') # ~57 miles from Washington, D.C.
    end

    context 'when there are representatives within the max search distance' do
      it 'returns all representatives located within the default max distance' do
        # check within 50 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072)

        expect(results.pluck(:representative_id)).to match_array(%w[123 456 789])
      end

      it 'returns all representatives located within the specified max distance' do
        # check within 40 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 64_373.8)

        expect(results.pluck(:representative_id)).to match_array(%w[456 789])
      end
    end

    context 'when there are no representatives within the max search distance' do
      it 'returns an empty array' do
        # check within 1 mile of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 1609.344)

        expect(results).to eq([])
      end
    end
  end

  describe 'callbacks' do
    describe '#set_full_name' do
      context 'creating a new representative' do
        it 'sets the full_name attribute as first_name + last_name' do
          rep = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: 'Joe',
                                    last_name: 'Smith')

          expect(rep.full_name).to be_nil

          rep.save!

          expect(rep.reload.full_name).to eq('Joe Smith')
        end
      end

      context 'updating an existing representative' do
        it 'sets the full_name attribute as first_name + last_name' do
          rep = create(:representative, first_name: 'Joe', last_name: 'Smith')

          expect(rep.full_name).to eq('Joe Smith')

          rep.update(first_name: 'Bob')

          expect(rep.reload.full_name).to eq('Bob Smith')
        end
      end
    end
  end
end
