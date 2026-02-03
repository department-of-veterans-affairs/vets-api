# frozen_string_literal: true

require 'rails_helper'
require 'bgs/power_of_attorney_verifier'

describe BGS::PowerOfAttorneyVerifier do
  let(:user) { create(:user, :loa3) }
  let(:identity) { create(:user_identity) }

  before do
    external_key = user.common_name || user.email
    allow(BGS::Services).to receive(:new).with({ external_uid: user.icn, external_key: })
    allow(Veteran::User).to receive(:new) { OpenStruct.new(power_of_attorney: PowerOfAttorney.new(code: 'A1Q')) }
    @veteran = Veteran::User.new(user)
    @veteran.power_of_attorney = PowerOfAttorney.new(code: 'A1Q')
  end

  it 'does not raise an exception if poa matches' do
    create(
      :representative,
      poa_codes: ['A1Q'],
      first_name: identity.first_name,
      last_name: identity.last_name
    )
    expect do
      BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.not_to raise_error
  end

  it 'raises an exception if poa does not matches' do
    create(
      :representative,
      poa_codes: ['B1Q'],
      first_name: identity.first_name,
      last_name: identity.last_name
    )
    expect do
      BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.to raise_error(Common::Exceptions::Unauthorized)
  end

  it 'raises an exception if representative not found' do
    expect do
      BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.to raise_error(Common::Exceptions::Unauthorized)
  end

  describe 'when multiple representatives have the same first name and last name' do
    before do
      allow(Veteran::Service::Representative).to receive(:all_for_user).with(
        hash_including(
          first_name: identity.first_name,
          last_name: identity.last_name
        )
      ).and_return(
        OpenStruct.new(count: 2)
      )
    end

    context 'and the authenticated user has a middle name' do
      let(:authenticated_user_middle_name) { 'Bruce' }

      before do
        identity.middle_name = authenticated_user_middle_name

        allow(Veteran::Service::Representative).to receive(:all_for_user).with(
          hash_including(
            first_name: identity.first_name,
            last_name: identity.last_name,
            middle_initial: 'B'
          )
        ).and_call_original
      end

      it "does an additional search using 'middle_initial'" do
        create(
          :representative,
          representative_id: '1234',
          poa_codes: ['A1Q'],
          first_name: identity.first_name,
          last_name: identity.last_name,
          middle_initial: 'B'
        )
        create(
          :representative,
          representative_id: '5678',
          poa_codes: ['B1Q'],
          first_name: identity.first_name,
          last_name: identity.last_name,
          middle_initial: 'X'
        )

        expect do
          BGS::PowerOfAttorneyVerifier.new(user).verify(identity)

          expect(Veteran::Service::Representative).to have_received(:all_for_user).with(
            hash_including(
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'B'
            )
          )
        end.not_to raise_error
      end

      context 'and the additional search returns a single result' do
        context 'and the poa code does match' do
          it 'does not error' do
            create(
              :representative,
              representative_id: '1234',
              poa_codes: ['A1Q'],
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'B'
            )
            create(
              :representative,
              representative_id: '5678',
              poa_codes: ['B1Q'],
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'X'
            )

            expect do
              BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
            end.not_to raise_error
          end
        end

        context 'and the poa code does not match' do
          it 'raises an error' do
            create(
              :representative,
              representative_id: '1234',
              poa_codes: ['NOT GONNA MATCH'],
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'B'
            )
            create(
              :representative,
              representative_id: '5678',
              poa_codes: ['B1Q'],
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'X'
            )

            expect do
              BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
            end.to raise_error { |error|
              expect(error.errors.first.detail).to eq("Power of Attorney code doesn't match Veteran's")
            }
          end
        end
      end

      context 'and the additional search still returns multiple results' do
        it "raises an error for 'ambiguity'" do
          create(
            :representative,
            representative_id: '1234',
            poa_codes: ['A1Q'],
            first_name: identity.first_name,
            last_name: identity.last_name,
            middle_initial: 'B'
          )
          create(
            :representative,
            representative_id: '5678',
            poa_codes: ['B1Q'],
            first_name: identity.first_name,
            last_name: identity.last_name,
            middle_initial: 'B'
          )

          expect do
            BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
          end.to raise_error { |error| expect(error.errors.first.detail).to eq('Ambiguous VSO Representative Results') }
        end
      end
    end

    context 'and the authenticated user does not have a middle name' do
      let(:authenticated_user_middle_name) { nil }

      it "raises an error for 'ambiguity'" do
        identity.middle_name = authenticated_user_middle_name

        expect do
          BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
        end.to raise_error { |error| expect(error.errors.first.detail).to eq('Ambiguous VSO Representative Results') }
      end
    end
  end

  describe 'when multiple representatives have the same first, last, and middle name' do
    before do
      allow(Veteran::Service::Representative).to receive(:all_for_user).with(
        hash_including(
          first_name: identity.first_name,
          last_name: identity.last_name
        )
      ).and_return(
        OpenStruct.new(count: 2)
      )
    end

    context 'and the authenticated user has a middle name' do
      let(:authenticated_user_middle_name) { 'Bruce' }

      before do
        identity.middle_name = authenticated_user_middle_name

        allow(Veteran::Service::Representative).to receive(:all_for_user).with(
          hash_including(
            first_name: identity.first_name,
            last_name: identity.last_name,
            middle_initial: 'B'
          )
        ).and_call_original

        allow(Veteran::Service::Representative).to receive(:all_for_user).with(
          hash_including(
            first_name: identity.first_name,
            last_name: identity.last_name,
            poa_code: 'A1Q'
          )
        ).and_call_original
      end

      it "does an additional search using 'poa_code'" do
        create(
          :representative,
          representative_id: '1234',
          poa_codes: ['A1Q'],
          first_name: identity.first_name,
          last_name: identity.last_name,
          middle_initial: 'B'
        )
        create(
          :representative,
          representative_id: '5678',
          poa_codes: ['B1Q'],
          first_name: identity.first_name,
          last_name: identity.last_name,
          middle_initial: 'B'
        )

        expect do
          BGS::PowerOfAttorneyVerifier.new(user).verify(identity)

          expect(Veteran::Service::Representative).to have_received(:all_for_user).with(
            hash_including(
              first_name: identity.first_name,
              last_name: identity.last_name,
              poa_code: 'A1Q'
            )
          )
        end.not_to raise_error
      end

      context 'and the additional search returns a single result' do
        context 'and the poa code does match' do
          it 'does not error' do
            create(
              :representative,
              representative_id: '1234',
              poa_codes: ['A1Q'],
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'B'
            )
            create(
              :representative,
              representative_id: '5678',
              poa_codes: ['B1Q'],
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'B'
            )

            expect do
              BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
            end.not_to raise_error
          end
        end

        context 'and the poa code does not match' do
          it 'raises an error' do
            create(
              :representative,
              representative_id: '1234',
              poa_codes: ['NOT GONNA MATCH'],
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'B'
            )
            create(
              :representative,
              representative_id: '5678',
              poa_codes: ['B1Q'],
              first_name: identity.first_name,
              last_name: identity.last_name,
              middle_initial: 'X'
            )

            expect do
              BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
            end.to raise_error { |error|
              expect(error.errors.first.detail).to eq("Power of Attorney code doesn't match Veteran's")
            }
          end
        end
      end

      context 'and the additional search still returns multiple results' do
        it "raises an error for 'ambiguity'" do
          create(
            :representative,
            representative_id: '1234',
            poa_codes: ['A1Q'],
            first_name: identity.first_name,
            last_name: identity.last_name,
            middle_initial: 'B'
          )
          create(
            :representative,
            representative_id: '5678',
            poa_codes: ['A1Q'],
            first_name: identity.first_name,
            last_name: identity.last_name,
            middle_initial: 'B'
          )

          expect do
            BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
          end.to raise_error { |error| expect(error.errors.first.detail).to eq('Ambiguous VSO Representative Results') }
        end
      end
    end
  end
end
