# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Representative, type: :model do
  let(:identity) { FactoryBot.create(:user_identity) }

  describe 'individual record' do
    it 'is valid with valid attributes' do
      expect(Veteran::Service::Representative.new(poa: '000')).to be_valid
    end

    it 'is not valid without a poa' do
      representative = Veteran::Service::Representative.new(poa: nil)
      expect(representative).to_not be_valid
    end
  end

  describe 'importer' do
    it 'should reload data from pulldown' do
      VCR.use_cassette('veteran/ogc_poa_data') do
        Veteran::Service::Representative.reload!
        expect(Veteran::Service::Representative.count).to eq 152
        expect(Veteran::Service::Organization.count).to eq 3
      end
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
      it 'should find a user by name, ssn, and dob' do
        expect(Veteran::Service::Representative.for_user(
          first_name: identity.first_name,
          last_name: identity.last_name,
          dob: identity.birth_date,
          ssn: identity.ssn
        ).id).to eq(rep.id)
      end

      it 'should find right user when 2 with the same name exist' do
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
      it 'should find a user by name fields' do
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
end
