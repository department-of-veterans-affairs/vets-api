# frozen_string_literal: true

require 'rails_helper'
require 'mhv/account_creation/service'

RSpec.describe User, type: :model do
  subject { described_class.new(build(:user, loa:)) }

  let(:loa) { loa_one }
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
          expect(user.icn).to be_nil
        end
      end
    end
  end

  describe '#needs_accepted_terms_of_use' do
    context 'when user is verified' do
      let(:user) { build(:user, :loa3, needs_accepted_terms_of_use: nil) }

      context 'and user has an associated current terms of use agreements' do
        let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account: user.user_account) }

        it 'does not return true' do
          expect(user.needs_accepted_terms_of_use).to be_falsey
        end
      end

      context 'and user does not have an associated current terms of use agreements' do
        it 'returns true' do
          expect(user.needs_accepted_terms_of_use).to be true
        end
      end
    end

    context 'when user is not verified' do
      let(:user) { build(:user, :loa1) }

      it 'does not return true' do
        expect(user.needs_accepted_terms_of_use).to be_falsey
      end
    end
  end

  describe 'vet360_contact_info' do
    let(:user) { build(:user, :loa3) }

    context 'when obtaining user contact info' do
      it 'returns VAProfileRedis::V2::ContactInformation info' do
        contact_info = user.vet360_contact_info
        expect(contact_info.class).to eq(VAProfileRedis::V2::ContactInformation)
        expect(contact_info.response.class).to eq(VAProfile::ContactInformation::V2::PersonResponse)
        expect(contact_info.mailing_address.class).to eq(VAProfile::Models::Address)
        expect(contact_info.email.email_address).to eq(user.va_profile_email)
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
      expect(user.authorize(:va_profile, :access?)).to be(true)
    end

    it 'returns false if user doesnt have edipi or icn' do
      expect(user).to receive(:edipi).and_return(nil)

      expect(user.authorize(:va_profile, :access?)).to be(false)
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

    describe 'validate_mpi_profile' do
      let(:loa) { loa_three }
      let(:id_theft_flag) { false }
      let(:deceased_date) { nil }

      before { stub_mpi(build(:mpi_profile, icn: user.icn, deceased_date:, id_theft_flag:)) }

      context 'when the user is not loa3' do
        let(:loa) { loa_one }

        it 'does not attempt to validate the user mpi profile' do
          expect(subject.validate_mpi_profile).to be_nil
        end
      end

      context 'when the MPI profile has a deceased date' do
        let(:deceased_date) { '20020202' }
        let(:expected_error_message) { 'Death Flag Detected' }

        it 'raises an MPI Account Locked error' do
          expect { subject.validate_mpi_profile }
            .to raise_error(MPI::Errors::AccountLockedError)
            .with_message(expected_error_message)
        end
      end

      context 'when the MPI profile has an identity theft flag' do
        let(:id_theft_flag) { true }
        let(:expected_error_message) { 'Theft Flag Detected' }

        it 'raises an MPI Account Locked error' do
          expect { subject.validate_mpi_profile }
            .to raise_error(MPI::Errors::AccountLockedError)
            .with_message(expected_error_message)
        end
      end

      context 'when the MPI profile has no issues' do
        it 'returns a nil value' do
          expect(subject.validate_mpi_profile).to be_nil
        end
      end
    end

    describe 'invalidate_mpi_cache' do
      let(:cache_exists) { true }

      before { allow_any_instance_of(MPIData).to receive(:cached?).and_return(cache_exists) }

      context 'when user is not loa3' do
        let(:loa) { loa_one }

        it 'does not attempt to clear the user mpi cache' do
          expect_any_instance_of(MPIData).not_to receive(:destroy)
          subject.invalidate_mpi_cache
        end
      end

      context 'when user is loa3' do
        let(:loa) { loa_three }

        context 'and mpi object exists with cached mpi response' do
          let(:cache_exists) { true }

          it 'clears the user mpi cache' do
            expect_any_instance_of(MPIData).to receive(:destroy)
            subject.invalidate_mpi_cache
          end
        end

        context 'and mpi object does not exist with cached mpi response' do
          let(:cache_exists) { false }

          it 'does not attempt to clear the user mpi cache' do
            expect_any_instance_of(MPIData).not_to receive(:destroy)
            subject.invalidate_mpi_cache
          end
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
          expect(user.vet360_id).to eq(vet360_id)
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

          it 'fetches preferred name from MPI' do
            expect(user.preferred_name).to eq(user.preferred_name_mpi)
          end

          context 'user has an address' do
            it 'returns mpi_profile\'s address as hash' do
              expect(user.address).to eq(expected_address)
              expect(user.address).to eq(user.send(:mpi_profile).address.attributes.deep_symbolize_keys)
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

        describe '#mhv_correlation_id' do
          let(:user) { build(:user, :loa3, mpi_profile:) }
          let(:mhv_user_account) { build(:mhv_user_account, user_profile_id: mhv_account_id) }
          let(:mpi_profile) { build(:mpi_profile, active_mhv_ids:) }
          let(:mhv_account_id) { 'some-id' }
          let(:active_mhv_ids) { [mhv_account_id] }
          let(:needs_accepted_terms_of_use) { false }

          context 'when the user is loa3' do
            let(:user) { build(:user, :loa3, needs_accepted_terms_of_use:, mpi_profile:) }

            context 'and the user has accepted the terms of use' do
              let(:needs_accepted_terms_of_use) { false }

              context 'and mhv_user_account is present' do
                before do
                  allow(user).to receive(:mhv_user_account).and_return(mhv_user_account)
                end

                it 'returns the user_profile_id from the mhv_user_account' do
                  expect(user.mhv_correlation_id).to eq(mhv_account_id)
                end
              end

              context 'and mhv_user_account is not present' do
                before do
                  allow(user).to receive(:mhv_user_account).and_return(nil)
                end

                context 'and the user has one active_mhv_ids' do
                  it 'returns the active_mhv_id' do
                    expect(user.mhv_correlation_id).to eq(active_mhv_ids.first)
                  end
                end

                context 'and the user has multiple active_mhv_ids' do
                  let(:active_mhv_ids) { %w[some-id another-id] }

                  it 'returns nil' do
                    expect(user.mhv_correlation_id).to be_nil
                  end
                end
              end
            end

            context 'and the user has not accepted the terms of use' do
              let(:needs_accepted_terms_of_use) { true }

              it 'returns nil' do
                expect(user.mhv_correlation_id).to be_nil
              end
            end
          end

          context 'when the user is not loa3' do
            let(:user) { build(:user, needs_accepted_terms_of_use:) }

            it 'returns nil' do
              expect(user.mhv_correlation_id).to be_nil
            end
          end
        end

        describe '#mhv_ids' do
          let(:user) { build(:user, :loa3) }

          it 'fetches mhv_ids from MPI' do
            expect(user.mhv_ids).to be(user.send(:mpi_profile).mhv_ids)
          end
        end

        describe '#active_mhv_ids' do
          let(:user) { build(:user, :loa3, active_mhv_ids:) }
          let(:active_mhv_ids) { [mhv_id] }
          let(:mhv_id) { 'some-mhv-id' }

          it 'fetches active_mhv_ids from MPI' do
            expect(user.active_mhv_ids).to eq(active_mhv_ids)
          end

          context 'when user has duplicate ids' do
            let(:active_mhv_ids) { [mhv_id, mhv_id] }
            let(:expected_active_mhv_ids) { [mhv_id] }

            it 'fetches unique active_mhv_ids from MPI' do
              expect(user.active_mhv_ids).to eq(expected_active_mhv_ids)
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
          expect(user.address[:street2]).to be(mpi_profile.address.street2)
          expect(user.address[:city]).to be(mpi_profile.address.city)
          expect(user.address[:postal_code]).to be(mpi_profile.address.postal_code)
          expect(user.address[:country]).to be(mpi_profile.address.country)
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
    let(:vha_facility_ids) { %w[200MHS 400 741 744 741MM] }
    let(:mpi_profile) { build(:mpi_profile, { vha_facility_ids: }) }
    let(:user) { build(:user, :loa3, vha_facility_ids: nil, mpi_profile:) }

    it 'filters out fake vha facility ids that arent in Settings.mhv.facility_range' do
      expect(user.va_treatment_facility_ids).to match_array(%w[400 744 741MM])
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
            expect(user.birth_date).to be_nil
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
          expect(user.birth_date).to be_nil
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
        expect(user.deceased_date).to be_nil
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
        expect(user.relationships).to be_nil
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
            expect(user.relationships).to be_nil
          end
        end
      end
    end
  end

  describe '#fingerprint' do
    let(:fingerprint) { '196.168.0.0' }
    let(:user) { create(:user, fingerprint:) }

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
        build(:user, :loa3, uuid:,
                            idme_uuid:, logingov_uuid:,
                            edipi:, mhv_credential_uuid:, authn_context:, icn:, user_verification:)
      )
    end
    let(:authn_context) { LOA::IDME_LOA1_VETS }
    let(:csp) { 'idme' }
    let(:logingov_uuid) { 'some-logingov-uuid' }
    let(:idme_uuid) { 'some-idme-uuid' }
    let(:edipi) { 'some-edipi' }
    let(:mhv_credential_uuid) { 'some-mhv-credential-uuid' }
    let(:icn) { 'some-icn' }
    let!(:user_verification) do
      Login::UserVerifier.new(login_type: csp,
                              auth_broker: 'iam',
                              mhv_uuid: mhv_credential_uuid,
                              idme_uuid:,
                              dslogon_uuid: edipi,
                              logingov_uuid:,
                              icn:).perform
    end
    let!(:user_account) { user_verification&.user_account }
    let(:uuid) { user_account.id }

    describe '#user_verification' do
      it 'returns expected user_verification' do
        expect(user.user_verification).to eq(user_verification)
      end

      context 'when user is logged in with mhv' do
        let(:csp) { 'mhv' }
        let(:authn_context) { 'myhealthevet' }

        context 'and there is an mhv_credential_uuid' do
          it 'returns user verification with a matching mhv_credential_uuid' do
            expect(user.user_verification.mhv_uuid).to eq(mhv_credential_uuid)
          end
        end

        context 'and there is not an mhv_credential_uuid' do
          let(:mhv_credential_uuid) { nil }

          context 'and user has an idme_uuid' do
            let(:idme_uuid) { 'some-idme-uuid' }

            it 'returns user verification with a matching idme_uuid' do
              expect(user.user_verification.idme_uuid).to eq(idme_uuid)
            end
          end

          context 'and user does not have an idme_uuid' do
            let(:idme_uuid) { nil }
            let(:user_verification) { nil }
            let(:uuid) { SecureRandom.uuid }

            it 'returns nil' do
              expect(user.user_verification).to be_nil
            end
          end
        end
      end

      context 'when user is logged in with dslogon' do
        let(:csp) { 'dslogon' }
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
            let(:uuid) { SecureRandom.uuid }

            it 'returns nil' do
              expect(user.user_verification).to be_nil
            end
          end
        end
      end

      context 'when user is logged in with logingov' do
        let(:authn_context) { IAL::LOGIN_GOV_IAL1 }
        let(:csp) { 'logingov' }

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
          let(:uuid) { SecureRandom.uuid }

          it 'returns nil' do
            expect(user.user_verification).to be_nil
          end
        end
      end
    end

    describe '#user_account' do
      it 'returns expected user_account' do
        expect(user.user_account).to eq(user_account)
      end
    end

    describe '#credential_lock' do
      context 'when the user has a UserVerification' do
        let(:user_verification) { create(:idme_user_verification, locked:) }
        let(:user) { build(:user, :loa3, user_verification:, idme_uuid: user_verification.idme_uuid) }
        let(:locked) { false }

        context 'when the UserVerification is not locked' do
          it 'returns false' do
            expect(user.credential_lock).to be(false)
          end
        end

        context 'when the UserVerification is locked' do
          let(:locked) { true }

          it 'returns true' do
            expect(user.credential_lock).to be(true)
          end
        end
      end

      context 'when the user does not have a UserVerification' do
        let(:user) { build(:user, :loa1, uuid: SecureRandom.uuid, user_verification: nil) }

        it 'returns nil' do
          expect(user.credential_lock).to be_nil
        end
      end
    end
  end

  describe '#onboarding' do
    let(:user) { create(:user) }

    before do
      Flipper.enable(:veteran_onboarding_beta_flow, user)
      Flipper.disable(:veteran_onboarding_show_to_newly_onboarded)
    end

    context "when feature toggle is enabled, show onboarding flow depending on user's preferences" do
      it 'show_onboarding_flow_on_login returns true when flag is enabled and display_onboarding_flow is true' do
        expect(user.show_onboarding_flow_on_login).to be true
      end

      it 'show_onboarding_flow_on_login returns false when flag is enabled but display_onboarding_flow is false' do
        user.onboarding.display_onboarding_flow = false
        expect(user.show_onboarding_flow_on_login).to be false
      end
    end

    context 'when feature toggle is disabled, never show onboarding flow' do
      it 'show_onboarding_flow_on_login returns false when flag is disabled, even if display_onboarding_flow is true' do
        Flipper.disable(:veteran_onboarding_beta_flow)
        Flipper.disable(:veteran_onboarding_show_to_newly_onboarded)
        expect(user.show_onboarding_flow_on_login).to be_falsey
      end
    end
  end

  describe '#mhv_user_account' do
    subject { user.mhv_user_account(from_cache_only:) }

    let(:user) { build(:user, :loa3) }
    let(:icn) { user.icn }
    let(:expected_cache_key) { "mhv_account_creation_#{icn}" }
    let(:user_account) { user.user_account }
    let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response: terms_of_use_response) }
    let(:terms_of_use_response) { 'accepted' }

    let(:mhv_client) { MHV::AccountCreation::Service.new }
    let(:mhv_response) do
      {
        user_profile_id: '12345678',
        premium: true,
        champ_va: true,
        patient: true,
        sm_account_created: true,
        message: 'some-message'
      }
    end
    let(:from_cache_only) { true }

    before do
      allow(Rails.logger).to receive(:info)
      allow(MHV::AccountCreation::Service).to receive(:new).and_return(mhv_client)
      allow(Rails.cache).to receive(:read).with(expected_cache_key).and_return(mhv_response)
    end

    context 'when from_cache_only is true' do
      let(:from_cache_only) { true }

      context 'and the mhv response is cached' do
        context 'when the user has all required attributes' do
          it 'returns a MHVUserAccount with the expected attributes' do
            mhv_user_account = subject

            expect(mhv_user_account).to be_a(MHVUserAccount)
            expect(mhv_user_account.attributes).to eq(mhv_response.with_indifferent_access)
          end
        end

        context 'and there is an error creating the account' do
          shared_examples 'mhv_user_account error' do
            let(:expected_log_message) { '[User] mhv_user_account error' }
            let(:expected_log_payload) { { error_message: /#{expected_error_message}/, icn: user.icn } }

            it 'logs and returns nil' do
              expect(subject).to be_nil
              expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
            end
          end

          context 'and the user does not have a terms_of_use_agreement' do
            let(:terms_of_use_agreement) { nil }
            let(:expected_error_message) { 'Current terms of use agreement must be present' }

            it_behaves_like 'mhv_user_account error'
          end

          context 'and the user has not accepted the terms of use' do
            let(:terms_of_use_response) { 'declined' }
            let(:expected_error_message) { "Current terms of use agreement must be 'accepted'" }

            it_behaves_like 'mhv_user_account error'
          end

          context 'and the user does not have an icn' do
            let(:user) { build(:user, :loa3, icn: nil) }
            let(:expected_error_message) { 'ICN must be present' }

            it_behaves_like 'mhv_user_account error'
          end
        end
      end

      context 'and the mhv response is not cached' do
        let(:mhv_response) { nil }

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end
    end

    context 'when from_cache_only is false' do
      let(:from_cache_only) { false }

      let(:mhv_service_response) do
        {
          user_profile_id: '12345678',
          premium: true,
          champ_va: true,
          patient: true,
          sm_account_created: true,
          message: 'some-message'
        }
      end

      before do
        allow_any_instance_of(MHV::AccountCreation::Service)
          .to receive(:create_account)
          .and_return(mhv_service_response)
      end

      context 'and the mhv response is cached' do
        context 'when the user has all required attributes' do
          it 'returns a MHVUserAccount with the expected attributes' do
            mhv_user_account = subject

            expect(mhv_user_account).to be_a(MHVUserAccount)
            expect(mhv_user_account.attributes).to eq(mhv_response.with_indifferent_access)
          end
        end

        context 'and there is an error creating the account' do
          shared_examples 'mhv_user_account error' do
            let(:expected_log_message) { '[User] mhv_user_account error' }
            let(:expected_log_payload) { { error_message: /#{expected_error_message}/, icn: user.icn } }

            it 'logs and returns nil' do
              expect(subject).to be_nil
              expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
            end
          end

          context 'and the user does not have a terms_of_use_agreement' do
            let(:terms_of_use_agreement) { nil }
            let(:expected_error_message) { 'Current terms of use agreement must be present' }

            it_behaves_like 'mhv_user_account error'
          end

          context 'and the user has not accepted the terms of use' do
            let(:terms_of_use_response) { 'declined' }
            let(:expected_error_message) { "Current terms of use agreement must be 'accepted'" }

            it_behaves_like 'mhv_user_account error'
          end

          context 'and the user does not have an icn' do
            let(:user) { build(:user, :loa3, icn: nil) }
            let(:expected_error_message) { 'ICN must be present' }

            it_behaves_like 'mhv_user_account error'
          end
        end
      end

      context 'and the mhv response is not cached' do
        let(:mhv_response) { nil }

        it 'returns result of calling MHV Account Creation Service' do
          expect(subject.attributes).to eq(mhv_service_response.with_indifferent_access)
        end
      end
    end
  end

  describe '#create_mhv_account_async' do
    let(:user) { build(:user, :loa3, needs_accepted_terms_of_use:) }
    let(:needs_accepted_terms_of_use) { false }
    let(:user_verification) { user.user_verification }

    before { allow(MHV::AccountCreatorJob).to receive(:perform_async) }

    context 'when the user is loa3' do
      let(:user) { build(:user, :loa3, needs_accepted_terms_of_use:) }

      context 'and the user has accepted the terms of use' do
        let(:needs_accepted_terms_of_use) { false }

        it 'enqueues a job to create the MHV account' do
          user.create_mhv_account_async

          expect(MHV::AccountCreatorJob).to have_received(:perform_async).with(user_verification.id)
        end
      end

      context 'and the user has not accepted the terms of use' do
        let(:needs_accepted_terms_of_use) { true }

        it 'does not enqueue a job to create the MHV account' do
          user.create_mhv_account_async

          expect(MHV::AccountCreatorJob).not_to have_received(:perform_async)
        end
      end
    end

    context 'when the user is not loa3' do
      let(:user) { build(:user, needs_accepted_terms_of_use:) }

      it 'does not enqueue a job to create the MHV account' do
        user.create_mhv_account_async

        expect(MHV::AccountCreatorJob).not_to have_received(:perform_async)
      end
    end
  end

  describe '#provision_cerner_async' do
    let(:user) { build(:user, :loa3, cerner_id:, cerner_facility_ids:) }
    let(:cerner_id) { 'some-cerner-id' }
    let(:cerner_facility_ids) { ['some-cerner-facility-id'] }

    before do
      allow(Identity::CernerProvisionerJob).to receive(:perform_async)
    end

    context 'when the user is loa3' do
      context 'when the user has a cerner_id' do
        it 'enqueues a job to provision the Cerner account' do
          user.provision_cerner_async

          expect(Identity::CernerProvisionerJob).to have_received(:perform_async).with(user.icn, nil)
        end
      end

      context 'when the user does not have a cerner_id nor cerner_facility_ids' do
        let(:cerner_id) { nil }
        let(:cerner_facility_ids) { [] }

        it 'does not enqueue a job to provision the Cerner account' do
          user.provision_cerner_async

          expect(Identity::CernerProvisionerJob).not_to have_received(:perform_async)
        end
      end
    end

    context 'when the user is not loa3' do
      let(:user) { build(:user, cerner_id:) }

      it 'does not enqueue a job to provision the Cerner account' do
        user.provision_cerner_async

        expect(Identity::CernerProvisionerJob).not_to have_received(:perform_async)
      end
    end
  end

  describe '#cerner_eligible?' do
    let(:user) { build(:user, :loa3, cerner_id:) }

    context 'when the user is loa3' do
      context 'when the user has a cerner_id' do
        let(:cerner_id) { 'some-cerner-id' }

        it 'returns true' do
          expect(user.cerner_eligible?).to be true
        end
      end

      context 'when the user does not have a cerner_id' do
        let(:cerner_id) { nil }

        it 'returns false' do
          expect(user.cerner_eligible?).to be false
        end
      end
    end

    context 'when the user is not loa3' do
      let(:user) { build(:user) }

      it 'returns false' do
        expect(user.cerner_eligible?).to be false
      end
    end
  end
end
