# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Representative, type: :model do
  let(:identity) { create(:user_identity) }

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
    let(:representative) do
      create(:representative,
             basic_attributes)
    end

    before do
      identity
      representative
    end

    describe 'finding by the name' do
      it 'finds a user' do
        expect(Veteran::Service::Representative.for_user(
          first_name: identity.first_name,
          last_name: identity.last_name
        ).id).to eq(representative.id)
      end

      it 'handles a nil value without throwing an exception' do
        expect(Veteran::Service::Representative.for_user(
                 first_name: identity.first_name,
                 last_name: nil
               )).to be_nil
      end
    end

    it 'finds right user when 2 with the same name exist' do
      create(:representative,
             basic_attributes)
      expect(Veteran::Service::Representative.for_user(
        first_name: identity.first_name,
        last_name: identity.last_name
      ).id).to eq(representative.id)
    end

    describe '#all_for_user' do
      it 'handles a nil value without throwing an exception' do
        expect(Veteran::Service::Representative.all_for_user(
                 first_name: identity.first_name,
                 last_name: nil,
                 middle_initial: 'J',
                 poa_code: '016'
               )).to eq([])
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

  describe '#organizations' do
    let(:representative) { create(:representative, poa_codes: %w[ABC 123]) }

    context 'when there are no organizations with the representative poa_codes' do
      it 'returns an empty array' do
        expect(representative.organizations).to eq([])
      end
    end

    context 'when there are organizations with the representative poa_codes' do
      it 'a list of those organizations' do
        organization1 = create(:organization, poa: 'ABC')
        organization2 = create(:organization, poa: '123')

        expect(representative.organizations).to contain_exactly(organization1, organization2)
      end
    end
  end

  describe 'callbacks' do
    describe '#set_full_name' do
      context 'creating a new representative' do
        it 'sets the full_name attribute as first_name + last_name' do
          representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: 'Joe',
                                               last_name: 'Smith')

          expect(representative.full_name).to be_nil

          representative.save!

          expect(representative.reload.full_name).to eq('Joe Smith')
        end
      end

      context 'updating an existing representative' do
        it 'sets the full_name attribute as first_name + last_name' do
          representative = create(:representative, first_name: 'Joe', last_name: 'Smith')

          expect(representative.full_name).to eq('Joe Smith')

          representative.update(first_name: 'Bob')

          expect(representative.reload.full_name).to eq('Bob Smith')
        end
      end

      context 'blank values' do
        context 'when first and last name are blank' do
          it 'sets full_name to empty string' do
            representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: ' ',
                                                 last_name: ' ')

            representative.save!

            expect(representative.reload.full_name).to eq('')
          end
        end

        context 'when first name is blank' do
          it 'sets full_name to last_name' do
            representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: ' ',
                                                 last_name: 'Smith')

            representative.save!

            expect(representative.reload.full_name).to eq('Smith')
          end
        end

        context 'when last name is blank' do
          it 'sets full_name to first_name' do
            representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: 'Bob',
                                                 last_name: ' ')

            representative.save!

            expect(representative.reload.full_name).to eq('Bob')
          end
        end

        context 'when first and last name are present' do
          it 'sets full_name to first_name + last_name' do
            representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: 'Bob',
                                                 last_name: 'Smith')

            representative.save!

            expect(representative.reload.full_name).to eq('Bob Smith')
          end
        end
      end
    end
  end

  describe '#diff' do
    context 'when there are changes in address' do
      let(:representative) do
        create(:representative,
               address_line1: '123 Main St',
               city: 'Anytown',
               zip_code: '12345',
               state_code: 'ST')
      end
      let(:new_data) do
        {
          address: {
            address_line1: '234 Main St',
            city: representative.city,
            zip_code5: representative.zip_code,
            zip_code4: representative.zip_suffix,
            state_province: { code: representative.state_code }
          },
          email: representative.email,
          phone_number: representative.phone_number
        }
      end

      it 'returns a hash indicating changes in address but not email or phone' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => true,
                                                      'email_changed' => false,
                                                      'phone_number_changed' => false
                                                    })
      end
    end

    context 'when there are changes in email' do
      let(:representative) do
        create(:representative,
               email: 'old@example.com')
      end
      let(:new_data) do
        {
          address: {
            address_line1: representative.address_line1,
            city: representative.city,
            zip_code5: representative.zip_code,
            zip_code4: representative.zip_suffix,
            state_province: { code: representative.state_code }
          },
          email: 'new@example.com',
          phone_number: representative.phone_number
        }
      end

      it 'returns a hash indicating changes in email but not address or phone' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => false,
                                                      'email_changed' => true,
                                                      'phone_number_changed' => false
                                                    })
      end
    end

    context 'when there are changes in phone' do
      let(:representative) do
        create(:representative,
               phone_number: '1234567890')
      end
      let(:new_data) do
        {
          address: {
            address_line1: representative.address_line1,
            city: representative.city,
            zip_code5: representative.zip_code,
            zip_code4: representative.zip_suffix,
            state_province: { code: representative.state_code }
          },
          email: representative.email,
          phone_number: '0987654321'
        }
      end

      it 'returns a hash indicating changes in phone but not address or email' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => false,
                                                      'email_changed' => false,
                                                      'phone_number_changed' => true
                                                    })
      end
    end

    context 'when there are no changes to address, email or phone' do
      let(:representative) do
        create(:representative,
               address_line1: '123 Main St',
               city: 'Anytown',
               zip_code: '12345',
               state_code: 'ST')
      end
      let(:new_data) do
        {
          address: {
            address_line1: representative.address_line1,
            city: representative.city,
            zip_code5: representative.zip_code,
            zip_code4: representative.zip_suffix,
            state_province: { code: representative.state_code }
          },
          email: representative.email,
          phone_number: representative.phone_number
        }
      end

      it 'returns a hash indicating no changes in address, email and phone number' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => false,
                                                      'email_changed' => false,
                                                      'phone_number_changed' => false
                                                    })
      end
    end
  end
end
