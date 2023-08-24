# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  subject { described_class.new(build(:user)) }

  let(:loa_one) { { current: LOA::ONE, highest: LOA::ONE } }
  let(:loa_three) { { current: LOA::THREE, highest: LOA::THREE } }
  let(:user) { build(:user, :loa3) }

  describe '#icn' do
    let(:user) { build(:user, icn: identity_icn) }
    let(:mpi_profile) { build(:mpi_profile, icn: mpi_icn) }
    let(:identity_icn) { 'some_identity_icn' }
    let(:mpi_icn) { 'some_mpi_icn' }

    before do
      allow(user).to receive(:mpi).and_return(mpi_profile)
    end

    context 'when icn on User Identity exists' do
      let(:identity_icn) { 'some_identity_icn' }

      it 'returns icn off the User Identity' do
        expect(user.icn).to eq(identity_icn)
      end
    end

    context 'when icn on identity does not exist' do
      let(:identity_icn) { nil }

      context 'and icn on MPI Data exists' do
        let(:mpi_icn) { 'some_mpi_icn' }

        it 'returns icn from the MPI Data' do
          expect(user.icn).to eq(mpi_icn)
        end
      end

      context 'and icn on MPI Data does not exist' do
        let(:mpi_icn) { nil }

        it 'returns nil' do
          expect(user.icn).to eq(nil)
        end
      end
    end
  end

  describe '#all_emails' do
    let(:user) { build(:user, :loa3, vet360_id: '12345') }
    let(:vet360_email) { user.vet360_contact_info.email.email_address }

    context 'when vet360 is down' do
      it 'returns user email' do
        expect(user).to receive(:vet360_contact_info).and_raise('foo')

        expect(user.all_emails).to eq([user.email])
      end
    end

    context 'when vet360 email is the same as user email' do
      it 'removes the duplicate email' do
        allow(user).to receive(:email).and_return(vet360_email.upcase)

        expect(user.all_emails).to eq([vet360_email])
      end
    end

    it 'returns identity and vet360 emails' do
      expect(user.all_emails).to eq([vet360_email, user.email])
    end
  end

  describe '#ssn_mismatch?', :skip_mvi do
    let(:mpi_ssn) { '918273384' }
    let(:mpi_profile) { build(:mpi_profile, { ssn: mpi_ssn }) }
    let(:user) { build(:user, :loa3, mpi_profile:) }

    it 'returns true if user loa3?, and ssns dont match' do
      expect(user).to be_ssn_mismatch
    end

    it 'returns false if user is not loa3?' do
      allow(user.identity).to receive(:loa3?).and_return(false)
      expect(user).not_to be_loa3
      expect(user.ssn).not_to eq(mpi_ssn)
      expect(user.ssn_mpi).to be_falsey
      expect(user).not_to be_ssn_mismatch
    end

    context 'identity ssn is nil' do
      let(:user) { build(:user, :loa3, ssn: nil, mpi_profile:) }

      it 'returns false' do
        expect(user).to be_loa3
        expect(user.ssn).to eq(mpi_ssn)
        expect(user.ssn_mpi).to be_truthy
        expect(user).not_to be_ssn_mismatch
      end
    end

    context 'mpi ssn is nil' do
      let(:mpi_profile) { build(:mpi_profile, { ssn: nil }) }

      it 'returns false' do
        expect(user).to be_loa3
        expect(user.ssn).to be_truthy
        expect(user.ssn_mpi).to be_falsey
        expect(user).not_to be_ssn_mismatch
      end
    end

    context 'matched ssn' do
      let(:user) { build(:user, :loa3) }

      it 'returns false if identity & mpi ssns match' do
        expect(user).to be_loa3
        expect(user.ssn).to be_truthy
        expect(user.ssn_mpi).to be_truthy
        expect(user).not_to be_ssn_mismatch
      end
    end
  end

  describe '#can_prefill_va_profile?' do
    it 'returns true if user has edipi or icn' do
      expect(user.authorize(:va_profile, :access?)).to eq(true)
    end

    it 'returns false if user doesnt have edipi or icn' do
      expect(user).to receive(:edipi).and_return(nil)

      expect(user.authorize(:va_profile, :access?)).to eq(false)
    end
  end

  describe '.create()' do
    context 'with LOA 1' do
      subject(:loa1_user) { described_class.new(build(:user, loa: loa_one)) }

      it 'does not allow a blank uuid' do
        loa1_user.uuid = ''
        expect(loa1_user).not_to be_valid
        expect(loa1_user.errors[:uuid].size).to be_positive
      end
    end

    context 'with LOA 1, and no highest will raise an exception on UserIdentity' do
      subject(:loa1_user) { described_class.new(build(:user, loa: { current: 1 })) }

      it 'raises an exception' do
        expect { loa1_user }.to raise_exception(Common::Exceptions::ValidationErrors)
      end
    end
  end

  it 'has a persisted attribute of false' do
    expect(subject).not_to be_persisted
  end

  describe 'redis persistence' do
    before { subject.save }

    describe '#save' do
      it 'sets persisted flag to true' do
        expect(subject).to be_persisted
      end

      it 'sets the ttl countdown' do
        expect(subject.ttl).to be_an(Integer)
        expect(subject.ttl).to be_between(0, 86_400)
      end
    end

    describe '.find' do
      let(:found_user) { described_class.find(subject.uuid) }

      it 'can find a saved user in redis' do
        expect(found_user).to be_a(described_class)
        expect(found_user.uuid).to eq(subject.uuid)
      end

      it 'expires and returns nil if user loaded from redis is invalid' do
        allow_any_instance_of(described_class).to receive(:valid?).and_return(false)
        expect(found_user).to be_nil
      end

      it 'returns nil if user was not found' do
        expect(described_class.find('non-existant-uuid')).to be_nil
      end
    end

    describe '#destroy' do
      it 'can destroy a user in redis' do
        expect(subject.destroy).to eq(1)
        expect(described_class.find(subject.uuid)).to be_nil
      end
    end

    describe 'invalidate_mpi_cache' do
      before { allow_any_instance_of(MPIData).to receive(:cached?).and_return(cache_exists) }

      context 'when mpi object exists with cached mpi response' do
        let(:cache_exists) { true }

        it 'clears the user mpi cache' do
          expect_any_instance_of(MPIData).to receive(:destroy)
          subject.invalidate_mpi_cache
        end
      end

      context 'when mpi object does not exist with cached mpi response' do
        let(:cache_exists) { false }

        it 'does not attempt to clear the user mpi cache' do
          expect_any_instance_of(MPIData).not_to receive(:destroy)
          subject.invalidate_mpi_cache
        end
      end
    end

    describe '#mpi_profile?' do
      context 'when user has mpi profile' do
        it 'returns true' do
          expect(user.mpi_profile?).to be(true)
        end
      end

      context 'when user does not have an mpi profile' do
        let(:user) { build(:user) }

        it 'returns false' do
          expect(user.mpi_profile?).to be(false)
        end
      end
    end

    describe 'getter methods' do
      context 'when saml user attributes available, icn is available, and user LOA3' do
        let(:vet360_id) { '1234567' }
        let(:mpi_profile) { build(:mpi_profile, { vet360_id: }) }
        let(:user) { build(:user, :loa3, mpi_profile:) }

        it 'fetches first_name from IDENTITY' do
          expect(user.first_name).to be(user.identity.first_name)
        end

        it 'fetches middle_name from IDENTITY' do
          expect(user.middle_name).to be(user.identity.middle_name)
        end

        it 'fetches last_name from IDENTITY' do
          expect(user.last_name).to be(user.identity.last_name)
        end

        it 'fetches gender from IDENTITY' do
          expect(user.gender).to be(user.identity.gender)
        end

        it 'fetches properly parsed birth_date from IDENTITY' do
          expect(user.birth_date).to eq(Date.parse(user.identity.birth_date).iso8601)
        end

        it 'fetches ssn from IDENTITY' do
          expect(user.ssn).to be(user.identity.ssn)
        end

        it 'fetches edipi from IDENTITY' do
          user.identity.edipi = '001001999'
          expect(user.edipi).to be(user.identity.edipi)
        end

        it 'has a vet360 id if one exists' do
          expect(user.vet360_id).to be(vet360_id)
        end
      end

      context 'when saml user attributes blank and user LOA3' do
        let(:mpi_profile) do
          build(:mpi_profile, { edipi: '1007697216',
                                given_names: [Faker::Name.first_name, Faker::Name.first_name],
                                family_name: Faker::Name.last_name,
                                gender: Faker::Gender.short_binary_type.upcase })
        end
        let(:user) do
          build(:user, :loa3, mpi_profile:,
                              edipi: nil, first_name: '', middle_name: '', last_name: '', gender: '')
        end

        it 'fetches edipi from MPI' do
          expect(user.edipi).to eq(user.edipi_mpi)
        end

        it 'fetches first_name from MPI' do
          expect(user.first_name).to eq(user.first_name_mpi)
        end

        it 'fetches middle_name from MPI' do
          expect(user.middle_name).to eq(user.middle_name_mpi)
        end

        it 'fetches last_name from MPI' do
          expect(user.last_name).to eq(user.last_name_mpi)
        end

        it 'fetches gender from MPI' do
          expect(user.gender).to eq(user.gender_mpi)
        end
      end

      context 'exclusively MPI sourced attributes' do
        context 'address attributes' do
          let(:user) { build(:user, :loa3, address: expected_address) }
          let(:expected_address) do
            { street: '123 Colfax Ave',
              street2: 'Unit 456',
              city: 'Denver',
              state: 'CO',
              postal_code: '80203',
              country: 'USA' }
          end

          context 'user has an address' do
            it 'returns mpi_profile\'s address as hash' do
              expect(user.address).to eq(expected_address)
              expect(user.address).to eq(user.send(:mpi_profile).address.to_h)
            end

            it 'returns mpi_profile\'s address postal code' do
              expect(user.postal_code).to eq(expected_address[:postal_code])
              expect(user.postal_code).to eq(user.send(:mpi_profile).address.postal_code)
            end
          end

          context 'user does not have an address' do
            before { user.send(:mpi_profile).address = nil }

            it 'returns a hash where all values are nil' do
              expect(user.address).to eq(
                { street: nil, street2: nil, city: nil, state: nil, country: nil, postal_code: nil }
              )
            end

            it 'returns nil postal code' do
              expect(user.postal_code).to be_nil
            end
          end
        end

        describe '#birls_id' do
          let(:user) { build(:user, :loa3, birls_id: mpi_birls_id) }
          let(:mpi_birls_id) { 'some_mpi_birls_id' }

          it 'returns birls_id from the MPI profile' do
            expect(user.birls_id).to eq(mpi_birls_id)
            expect(user.birls_id).to eq(user.send(:mpi_profile).birls_id)
          end
        end

        context 'CERNER ids' do
          let(:user) do
            build(:user, :loa3,
                  cerner_id:, cerner_facility_ids:)
          end
          let(:cerner_id) { 'some-cerner-id' }
          let(:cerner_facility_ids) { %w[123 456] }

          it 'returns cerner_id from the MPI profile' do
            expect(user.cerner_id).to eq(cerner_id)
            expect(user.cerner_id).to eq(user.send(:mpi_profile).cerner_id)
          end

          it 'returns cerner_facility_ids from the MPI profile' do
            expect(user.cerner_facility_ids).to eq(cerner_facility_ids)
            expect(user.cerner_facility_ids).to eq(user.send(:mpi_profile).cerner_facility_ids)
          end
        end

        describe '#edipi_mpi' do
          let(:user) { build(:user, :loa3, edipi: expected_edipi) }
          let(:expected_edipi) { '1234567890' }

          it 'fetches edipi from MPI' do
            expect(user.edipi_mpi).to eq(expected_edipi)
            expect(user.edipi_mpi).to eq(user.send(:mpi_profile).edipi)
          end
        end

        describe '#gender_mpi' do
          let(:user) { build(:user, :loa3, gender: expected_gender) }
          let(:expected_gender) { 'F' }

          it 'fetches gender from MPI' do
            expect(user.gender_mpi).to eq(expected_gender)
            expect(user.gender_mpi).to eq(user.send(:mpi_profile).gender)
          end
        end

        describe '#home_phone' do
          let(:user) { build(:user, :loa3, home_phone:) }
          let(:home_phone) { '315-867-5309' }

          it 'returns home_phone from the MPI profile' do
            expect(user.home_phone).to eq(home_phone)
            expect(user.home_phone).to eq(user.send(:mpi_profile).home_phone)
          end
        end

        context 'name attributes' do
          let(:user) do
            build(:user, :loa3,
                  first_name:, middle_name:, last_name:, suffix:)
          end
          let(:first_name) { 'some-first-name' }
          let(:middle_name) { 'some-middle-name' }
          let(:last_name) { 'some-last-name' }
          let(:suffix) { 'some-suffix' }
          let(:expected_given_names) { [first_name, middle_name] }
          let(:expected_common_name) { "#{first_name} #{middle_name} #{last_name} #{suffix}" }

          it 'fetches first_name from MPI' do
            expect(user.first_name_mpi).to eq(first_name)
            expect(user.first_name_mpi).to eq(user.send(:mpi_profile).given_names&.first)
          end

          it 'fetches last_name from MPI' do
            expect(user.last_name_mpi).to eq(last_name)
            expect(user.last_name_mpi).to eq(user.send(:mpi_profile).family_name)
          end

          it 'returns an expected generated common name string' do
            expect(user.common_name).to eq(expected_common_name)
          end

          it 'fetches given_names from MPI' do
            expect(user.given_names).to eq(expected_given_names)
            expect(user.given_names).to eq(user.send(:mpi_profile).given_names)
          end

          it 'fetches suffix from MPI' do
            expect(user.suffix).to eq(suffix)
            expect(user.suffix).to eq(user.send(:mpi_profile).suffix)
          end
        end

        context 'MHV ids' do
          let(:user) { build(:user, :loa3, mhv_correlation_id: nil, participant_id:) }
          let(:participant_id) { 'some_mpi_participant_id' }

          context 'when mhv ids are nil' do
            let(:participant_id) { nil }

            it 'has a mhv correlation id of nil' do
              expect(user.mhv_correlation_id).to be_nil
            end
          end

          context 'when there are mhv ids' do
            it 'fetches mhv correlation id from MPI' do
              expect(user.mhv_correlation_id).to eq(user.send(:mpi_profile).mhv_ids.first)
              expect(user.mhv_correlation_id).to eq(user.send(:mpi_profile).active_mhv_ids.first)
            end

            it 'fetches mhv_ids from MPI' do
              expect(user.mhv_ids).to be(user.send(:mpi_profile).mhv_ids)
            end

            it 'fetches active_mhv_ids from MPI' do
              expect(user.active_mhv_ids).to be(user.send(:mpi_profile).active_mhv_ids)
            end
          end
        end

        describe '#participant_id' do
          let(:user) { build(:user, :loa3, participant_id: mpi_participant_id) }
          let(:mpi_participant_id) { 'some_mpi_participant_id' }

          it 'returns participant_id from the MPI profile' do
            expect(user.participant_id).to eq(mpi_participant_id)
            expect(user.participant_id).to eq(user.send(:mpi_profile).participant_id)
          end
        end

        describe '#person_types' do
          let(:user) { build(:user, :loa3, person_types: expected_person_types) }
          let(:expected_person_types) { %w[DEP VET] }

          it 'returns person_types from the MPI profile' do
            expect(user.person_types).to eq(expected_person_types)
            expect(user.person_types).to eq(user.send(:mpi_profile).person_types)
          end
        end

        describe '#ssn_mpi' do
          let(:user) { build(:user, :loa3, ssn: expected_ssn) }
          let(:expected_ssn) { '296333851' }

          it 'returns ssn from the MPI profile' do
            expect(user.ssn_mpi).to eq(expected_ssn)
            expect(user.ssn_mpi).to eq(user.send(:mpi_profile).ssn)
          end
        end

        context 'VHA facility ids' do
          let(:user) do
            build(:user, :loa3,
                  vha_facility_ids:, vha_facility_hash:)
          end
          let(:vha_facility_ids) { %w[200CRNR 200MHV] }
          let(:vha_facility_hash) { { '200CRNR' => %w[123456], '200MHV' => %w[123456] } }

          it 'returns vha_facility_ids from the MPI profile' do
            expect(user.vha_facility_ids).to eq(vha_facility_ids)
            expect(user.vha_facility_ids).to eq(user.send(:mpi_profile).vha_facility_ids)
          end

          it 'returns vha_facility_hash from the MPI profile' do
            expect(user.vha_facility_hash).to eq(vha_facility_hash)
            expect(user.vha_facility_hash).to eq(user.send(:mpi_profile).vha_facility_hash)
          end
        end
      end

      describe '#vha_facility_hash' do
        let(:vha_facility_hash) { { '400' => %w[123456789 999888777] } }
        let(:mpi_profile) { build(:mpi_profile, { vha_facility_hash: }) }
        let(:user) { build(:user, :loa3, vha_facility_hash: nil, mpi_profile:) }

        it 'returns the users vha_facility_hash' do
          expect(user.vha_facility_hash).to eq(vha_facility_hash)
        end
      end

      describe 'set_mhv_ids do' do
        before { user.set_mhv_ids('1234567890') }

        it 'sets new mhv ids to a users MPI profile' do
          expect(user.mhv_ids).to include('1234567890')
          expect(user.active_mhv_ids).to include('1234567890')
        end
      end

      context 'when saml user attributes NOT available, icn is available, and user LOA3' do
        let(:given_names) { [Faker::Name.first_name] }
        let(:mpi_profile) { build(:mpi_profile, given_names:) }
        let(:user) do
          build(:user, :loa3, mpi_profile:,
                              first_name: nil, last_name: nil, birth_date: nil, ssn: nil, gender: nil, address: nil)
        end

        it 'fetches first_name from MPI' do
          expect(user.first_name).to be(user.first_name_mpi)
        end

        context 'when given_names has no middle_name' do
          it 'fetches middle name from MPI' do
            expect(user.middle_name).to be_nil
          end
        end

        context 'when given_names has middle_name' do
          let(:given_names) { [Faker::Name.first_name, Faker::Name.first_name] }

          it 'fetches middle name from MPI' do
            expect(user.middle_name).to eq(given_names[1])
          end
        end

        context 'when given_names has multiple middle names' do
          let(:given_names) { [Faker::Name.first_name, Faker::Name.first_name, Faker::Name.first_name] }
          let(:expected_middle_names) { given_names.drop(1).join(' ') }

          it 'fetches middle name from MPI' do
            expect(user.middle_name).to eq(expected_middle_names)
          end
        end

        it 'fetches last_name from MPI' do
          expect(user.last_name).to be(user.last_name_mpi)
        end

        it 'fetches gender from MPI' do
          expect(user.gender).to be(user.gender_mpi)
        end

        it 'fetches properly parsed birth_date from MPI' do
          expect(user.birth_date).to eq(Date.parse(user.birth_date_mpi).iso8601)
        end

        it 'fetches address data from MPI and stores it as a hash' do
          expect(user.address[:street]).to eq(mpi_profile.address.street)
          expect(user.address[:street2]).to be(mpi_profile.address[:street2])
          expect(user.address[:city]).to be(mpi_profile.address[:city])
          expect(user.address[:postal_code]).to be(mpi_profile.address[:postal_code])
          expect(user.address[:country]).to be(mpi_profile.address[:country])
        end

        it 'fetches ssn from MPI' do
          expect(user.ssn).to be(user.ssn_mpi)
        end
      end

      context 'when saml user attributes NOT available, icn is available, and user NOT LOA3' do
        let(:mpi_profile) { build(:mpi_profile) }
        let(:user) do
          build(:user, :loa1, mpi_profile:, mhv_icn: mpi_profile.icn,
                              first_name: nil, last_name: nil, birth_date: nil, ssn: nil, gender: nil, address: nil)
        end

        it 'fetches first_name from IDENTITY' do
          expect(user.first_name).to be_nil
        end

        it 'fetches middle_name from IDENTITY' do
          expect(user.middle_name).to be_nil
        end

        it 'fetches last_name from IDENTITY' do
          expect(user.last_name).to be_nil
        end

        it 'fetches gender from IDENTITY' do
          expect(user.gender).to be_nil
        end

        it 'fetches birth_date from IDENTITY' do
          expect(user.birth_date).to be_nil
        end

        it 'fetches ssn from IDENTITY' do
          expect(user.ssn).to be_nil
        end
      end

      context 'when icn is not available from saml data' do
        it 'fetches first_name from IDENTITY' do
          expect(user.first_name).to be(user.identity.first_name)
        end

        it 'fetches middle_name from IDENTITY' do
          expect(user.middle_name).to be(user.identity.middle_name)
        end

        it 'fetches last_name from IDENTITY' do
          expect(user.last_name).to be(user.identity.last_name)
        end

        it 'fetches gender from IDENTITY' do
          expect(user.gender).to be(user.identity.gender)
        end

        it 'fetches properly parsed birth_date from IDENTITY' do
          expect(user.birth_date).to eq(Date.parse(user.identity.birth_date).iso8601)
        end

        it 'fetches ssn from IDENTITY' do
          expect(user.ssn).to be(user.identity.ssn)
        end
      end
    end
  end

  describe '#flipper_id' do
    it 'returns a unique identifier of email' do
      expect(user.flipper_id).to eq(user.email)
    end
  end

  describe '#va_patient?' do
    let(:user) { build(:user, :loa3, vha_facility_ids:) }
    let(:vha_facility_ids) { [] }

    around do |example|
      with_settings(Settings.mhv, facility_range: [[450, 758]]) do
        with_settings(Settings.mhv, facility_specific: ['759MM']) do
          example.run
        end
      end
    end

    context 'when there are no facilities' do
      it 'is false' do
        expect(user).not_to be_va_patient
      end
    end

    context 'when there are nil facilities' do
      let(:vha_facility_ids) { nil }

      it 'is false' do
        expect(user).not_to be_va_patient
      end
    end

    context 'when there are no facilities in the defined range' do
      let(:vha_facility_ids) { [200, 759] }

      it 'is false' do
        expect(user).not_to be_va_patient
      end
    end

    context 'when facility is at the bottom edge of range' do
      let(:vha_facility_ids) { [450] }

      it 'is true' do
        expect(user).to be_va_patient
      end
    end

    context 'when alphanumeric facility is at the bottom edge of range' do
      let(:vha_facility_ids) { %w[450MH] }

      it 'is true' do
        expect(user).to be_va_patient
      end
    end

    context 'when facility is at the top edge of range' do
      let(:vha_facility_ids) { [758] }

      it 'is true' do
        expect(user).to be_va_patient
      end
    end

    context 'when alphanumeric facility is at the top edge of range' do
      let(:vha_facility_ids) { %w[758MH] }

      it 'is true' do
        expect(user).to be_va_patient
      end
    end

    context 'when there are multiple alphanumeric facilities all within defined range' do
      let(:vha_facility_ids) { %w[450MH 758MH] }

      it 'is true' do
        expect(user).to be_va_patient
      end
    end

    context 'when there are multiple facilities all outside of defined range' do
      let(:vha_facility_ids) { %w[449MH 759MH] }

      it 'is false' do
        expect(user).not_to be_va_patient
      end
    end

    context 'when it matches exactly to a facility_specific' do
      let(:vha_facility_ids) { %w[759MM] }

      it 'is true' do
        expect(user).to be_va_patient
      end
    end

    context 'when it does not match exactly to a facility_specific and is outside of ranges' do
      let(:vha_facility_ids) { %w[759] }

      it 'is false' do
        expect(user).not_to be_va_patient
      end
    end
  end

  describe '#va_treatment_facility_ids' do
    let(:vha_facility_ids) { %w[200MHS 400 741 744] }
    let(:mpi_profile) { build(:mpi_profile, { vha_facility_ids: }) }
    let(:user) { build(:user, :loa3, vha_facility_ids: nil, mpi_profile:) }

    it 'filters out fake vha facility ids that arent in Settings.mhv.facility_range' do
      expect(user.va_treatment_facility_ids).to match_array(%w[400 744])
    end
  end

  describe '#pciu' do
    context 'when user is LOA3 and has an edipi' do
      before { stub_evss_pciu(user) }

      it 'returns pciu_email' do
        expect(user.pciu_email).to eq 'test2@test1.net'
      end

      it 'returns pciu_primary_phone' do
        expect(user.pciu_primary_phone).to eq '14445551212'
      end

      it 'returns pciu_alternate_phone' do
        expect(user.pciu_alternate_phone).to eq '1'
      end
    end

    context 'when user is LOA1' do
      let(:user) { build(:user, :loa1) }

      it 'returns blank pciu_email' do
        expect(user.pciu_email).to eq nil
      end

      it 'returns blank pciu_primary_phone' do
        expect(user.pciu_primary_phone).to eq nil
      end

      it 'returns blank pciu_alternate_phone' do
        expect(user.pciu_alternate_phone).to eq nil
      end
    end
  end

  describe '#account' do
    context 'when user has an existing Account record' do
      let(:user) { create :user, :accountable }

      it 'returns the users Account record' do
        account = Account.find_by(idme_uuid: user.uuid)

        expect(user.account).to eq account
      end
    end

    context 'when user does not have an existing Account record' do
      let(:user) { create :user, :loa3 }

      before do
        account = Account.find_by(idme_uuid: user.uuid)
        account.destroy
      end

      it 'creates and returns the users Account record', :aggregate_failures do
        account = Account.find_by(idme_uuid: user.uuid)
        expect(account).to be_nil
        account = user.account

        expect(account.class).to eq Account
        expect(account.idme_uuid).to eq user.uuid
      end
    end
  end

  describe '#birth_date' do
    let(:user) { subject }

    context 'when birth_date attribute is available on the UserIdentity object' do
      it 'returns iso8601 parsed date from the UserIdentity birth_date attribute' do
        expect(user.birth_date).to eq Date.parse(user.identity.birth_date.to_s).iso8601
      end
    end

    context 'when birth_date attribute is not available on the UserIdentity object' do
      before do
        allow(user.identity).to receive(:birth_date).and_return nil
      end

      context 'and mhv_icn attribute is available on the UserIdentity object' do
        let(:mpi_profile) { build(:mpi_profile) }
        let(:user) { described_class.new(build(:user, :mhv, mhv_icn: 'some-mhv-icn', mpi_profile:)) }

        context 'and MPI Profile birth date does not exist' do
          let(:mpi_profile) { build(:mpi_profile, { birth_date: nil }) }

          it 'returns nil' do
            expect(user.birth_date).to eq nil
          end
        end

        context 'and MPI Profile birth date does exist' do
          it 'returns iso8601 parsed date from the MPI Profile birth_date attribute' do
            expect(user.birth_date).to eq Date.parse(user.birth_date_mpi.to_s).iso8601
          end
        end
      end

      context 'when birth_date attribute cannot be retrieved from UserIdentity or MPI object' do
        before do
          allow(user.identity).to receive(:birth_date).and_return nil
        end

        it 'returns nil' do
          expect(user.birth_date).to eq nil
        end
      end
    end
  end

  describe '#deceased_date' do
    let!(:user) { described_class.new(build(:user, :mhv, mhv_icn: 'some-mhv-icn')) }

    context 'and MPI Profile deceased date does not exist' do
      before do
        allow_any_instance_of(MPI::Models::MviProfile).to receive(:deceased_date).and_return nil
      end

      it 'returns nil' do
        expect(user.deceased_date).to eq nil
      end
    end

    context 'and MPI Profile deceased date does exist' do
      let(:mpi_profile) { build(:mpi_profile, deceased_date:) }
      let(:deceased_date) { '20200202' }

      before do
        stub_mpi(mpi_profile)
      end

      it 'returns iso8601 parsed date from the MPI Profile deceased_date attribute' do
        expect(user.deceased_date).to eq Date.parse(deceased_date).iso8601
      end
    end
  end

  describe '#relationships' do
    let(:user) { described_class.new(build(:user_with_relationship)) }

    before do
      allow_any_instance_of(MPI::Models::MviProfile).to receive(:relationships).and_return(mpi_relationship_array)
    end

    context 'when user is not loa3' do
      let(:user) { described_class.new(build(:user, :loa1)) }
      let(:mpi_relationship_array) { [] }

      it 'returns nil' do
        expect(user.relationships).to eq nil
      end
    end

    context 'when user is loa3' do
      context 'when there are relationship entities in the MPI response' do
        let(:mpi_relationship_array) { [mpi_relationship] }
        let(:mpi_relationship) { build(:mpi_profile_relationship) }
        let(:user_relationship_double) { double }
        let(:expected_user_relationship_array) { [user_relationship_double] }

        before do
          allow(UserRelationship).to receive(:from_mpi_relationship)
            .with(mpi_relationship).and_return(user_relationship_double)
        end

        it 'returns an array of UserRelationship objects representing the relationship entities' do
          expect(user.relationships).to eq expected_user_relationship_array
        end
      end

      context 'when there are not relationship entities in the MPI response' do
        let(:mpi_relationship_array) { nil }
        let(:bgs_dependent_response) { nil }

        before do
          allow_any_instance_of(BGS::DependentService).to receive(:get_dependents).and_return(bgs_dependent_response)
        end

        it 'makes a call to the BGS for relationship information' do
          expect_any_instance_of(BGS::DependentService).to receive(:get_dependents)
          user.relationships
        end

        context 'when BGS relationship response contains information' do
          let(:bgs_relationship_array) { [bgs_dependent] }
          let(:bgs_dependent) do
            {
              'award_indicator' => 'N',
              'city_of_birth' => 'WASHINGTON',
              'current_relate_status' => '',
              'date_of_birth' => '01/01/2000',
              'date_of_death' => '',
              'death_reason' => '',
              'email_address' => 'Curt@email.com',
              'first_name' => 'CURT',
              'gender' => '',
              'last_name' => 'WEBB-STER',
              'middle_name' => '',
              'proof_of_dependency' => 'Y',
              'ptcpnt_id' => '32354974',
              'related_to_vet' => 'N',
              'relationship' => 'Child',
              'ssn' => '500223351',
              'ssn_verify_status' => '1',
              'state_of_birth' => 'DC'
            }
          end
          let(:bgs_dependent_response) { { persons: [bgs_dependent] } }
          let(:user_relationship_double) { double }
          let(:expected_user_relationship_array) { [user_relationship_double] }

          before do
            allow(UserRelationship).to receive(:from_bgs_dependent)
              .with(bgs_dependent).and_return(user_relationship_double)
          end

          it 'returns an array of UserRelationship objects representing the relationship entities' do
            expect(user.relationships).to eq expected_user_relationship_array
          end
        end

        context 'when BGS relationship response does not contain information' do
          it 'returns an empty array' do
            expect(user.relationships).to eq nil
          end
        end
      end
    end
  end

  describe '#fingerprint' do
    let(:fingerprint) { '196.168.0.0' }
    let(:user) { create :user, fingerprint: }

    it 'returns expected user fingerprint' do
      expect(user.fingerprint).to eq(fingerprint)
    end

    context 'fingerprint mismatch' do
      let(:new_fingerprint) { '0.0.0.0' }

      it 'can update the user fingerprint value' do
        user.fingerprint = new_fingerprint
        expect(user.fingerprint).to eq(new_fingerprint)
      end
    end
  end

  context 'user_verification methods' do
    let(:user) do
      described_class.new(
        build(:user, :loa3,
              idme_uuid:, logingov_uuid:,
              edipi:, mhv_correlation_id:, authn_context:)
      )
    end
    let(:user_verifier_object) do
      OpenStruct.new({ idme_uuid:, logingov_uuid:, sign_in: user.identity_sign_in,
                       edipi:, mhv_correlation_id: })
    end
    let(:authn_context) { LOA::IDME_LOA1_VETS }
    let(:logingov_uuid) { 'some-logingov-uuid' }
    let(:idme_uuid) { 'some-idme-uuid' }
    let(:edipi) { 'some-edipi' }
    let(:mhv_correlation_id) { 'some-mhv-correlation-id' }
    let!(:user_verification) { Login::UserVerifier.new(user_verifier_object).perform }
    let!(:user_account) { user_verification&.user_account }

    describe '#user_verification' do
      it 'returns expected user_verification' do
        expect(user.user_verification).to eq(user_verification)
      end

      context 'when user is logged in with mhv' do
        let(:authn_context) { 'myhealthevet' }

        context 'and there is an mhv_correlation_id' do
          it 'returns user verification with a matching mhv_correlation_id' do
            expect(user.user_verification.mhv_uuid).to eq(mhv_correlation_id)
          end
        end

        context 'and there is not an mhv_correlation_id' do
          let(:mhv_correlation_id) { nil }

          context 'and user has an idme_uuid' do
            let(:idme_uuid) { 'some-idme-uuid' }

            it 'returns user verification with a matching idme_uuid' do
              expect(user.user_verification.idme_uuid).to eq(idme_uuid)
            end
          end

          context 'and user does not have an idme_uuid' do
            let(:idme_uuid) { nil }
            let(:user_verification) { nil }

            it 'returns nil' do
              expect(user.user_verification).to be nil
            end
          end
        end
      end

      context 'when user is logged in with dslogon' do
        let(:authn_context) { 'dslogon' }

        context 'and there is an edipi' do
          let(:edipi) { 'some-edipi' }

          it 'returns user verification with a matching edipi' do
            expect(user.user_verification.dslogon_uuid).to eq(edipi)
          end
        end

        context 'and there is not an edipi' do
          let(:edipi) { nil }

          context 'and user has an idme_uuid' do
            let(:idme_uuid) { 'some-idme-uuid' }

            it 'returns user verification with a matching idme_uuid' do
              expect(user.user_verification.idme_uuid).to eq(idme_uuid)
            end
          end

          context 'and user does not have an idme_uuid' do
            let(:idme_uuid) { nil }
            let(:user_verification) { nil }

            it 'returns nil' do
              expect(user.user_verification).to be nil
            end
          end
        end
      end

      context 'when user is logged in with logingov' do
        let(:authn_context) { IAL::LOGIN_GOV_IAL1 }
        let(:logingov_uuid) { 'some-logingov-uuid' }

        it 'returns user verification with a matching logingov uuid' do
          expect(user.user_verification.logingov_uuid).to eq(logingov_uuid)
        end
      end

      context 'when user is logged in with idme' do
        let(:authn_context) { LOA::IDME_LOA1_VETS }

        context 'and user has an idme_uuid' do
          let(:idme_uuid) { 'some-idme-uuid' }

          it 'returns user verification with a matching idme_uuid' do
            expect(user.user_verification.idme_uuid).to eq(idme_uuid)
          end
        end

        context 'and user does not have an idme_uuid' do
          let(:idme_uuid) { nil }
          let(:user_verification) { nil }

          it 'returns nil' do
            expect(user.user_verification).to be nil
          end
        end
      end
    end

    describe '#user_account' do
      it 'returns expected user_account' do
        expect(user.user_account).to eq(user_account)
      end
    end

    describe '#inherited_proof_verified' do
      context 'when Inherited Proof Verified User Account exists and matches current user_account' do
        let!(:inherited_proof_verified) { create(:inherited_proof_verified_user_account, user_account:) }

        it 'returns true' do
          expect(user.inherited_proof_verified).to be true
        end
      end

      context 'when no Inherited Proof Verified User Account is found' do
        it 'returns false' do
          expect(user.inherited_proof_verified).to be false
        end
      end
    end
  end
end
