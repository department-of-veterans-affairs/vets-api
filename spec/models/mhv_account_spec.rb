# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MhvAccount, type: :model do
  let(:mvi_profile) do
    build(:mvi_profile,
          icn: '1012667122V019349',
          given_names: %w[Hector],
          family_name: 'Allen',
          suffix: nil,
          gender: 'M',
          birth_date: '1932-02-05',
          ssn: '796126859',
          mhv_ids: mhv_ids,
          vha_facility_ids: vha_facility_ids,
          home_phone: nil,
          address: mvi_profile_address)
  end

  let(:mvi_profile_address) do
    build(:mvi_profile_address,
          street: '20140624',
          city: 'Houston',
          state: 'TX',
          country: 'USA',
          postal_code: '77040')
  end

  let(:user) do
    create(:user, :loa3,
           ssn: user_ssn,
           first_name: mvi_profile.given_names.first,
           last_name: mvi_profile.family_name,
           gender: mvi_profile.gender,
           birth_date: mvi_profile.birth_date,
           email: 'vets.gov.user+0@gmail.com')
  end

  let(:user_ssn) { mvi_profile.ssn }

  let(:mhv_ids) { [] }
  let(:vha_facility_ids) { ['450'] }

  before(:each) do
    stub_mvi(mvi_profile)
  end

  around(:each) do |example|
    with_settings(Settings.mhv, facility_range: [[358, 718], [720, 758]]) do
      example.run
    end
  end

  it 'must have a user_uuid when initialized' do
    expect { described_class.new }
      .to raise_error(StandardError, 'You must use find_or_initialize_by(user_uuid: #)')
  end

  describe 'event' do
    context 'check_eligibility' do
      context 'with terms accepted' do
        let(:terms) { create(:terms_and_conditions, latest: true, name: described_class::TERMS_AND_CONDITIONS_NAME) }
        before(:each) { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid) }

        let(:base_attributes) { { user_uuid: user.uuid, account_state: 'needs_terms_acceptance' } }

        context 'ssn mismatch' do
          let(:user_ssn) { '123456789' }

          it 'is needs_ssn_resolution if ssn is mismatched' do
            subject = described_class.new(base_attributes)
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('needs_ssn_resolution')
            expect(subject.terms_and_conditions_accepted?).to be_truthy
            expect(subject.creatable?).to be_falsey
          end
        end

        context 'not a va patient' do
          let(:vha_facility_ids) { ['999'] }

          it 'is needs_va_patient if not a va patient' do
            subject = described_class.new(base_attributes)
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('needs_va_patient')
            expect(subject.terms_and_conditions_accepted?).to be_truthy
            expect(subject.creatable?).to be_falsey
          end
        end

        context 'with mhv id' do
          let(:mhv_ids) { ['14221465'] }
          let(:base_attributes) { { user_uuid: user.uuid } }

          it 'a priori registered account stays registered' do
            subject = described_class.new(
              base_attributes.merge(registered_at: Time.current, account_state: :registered)
            )
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('registered')
            expect(subject.creatable?).to be_truthy
          end

          it 'a priori failed upgrade that has been registered changes to registered' do
            subject = described_class.new(
              base_attributes.merge(registered_at: Time.current, account_state: :upgrade_failed)
            )
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('registered')
          end

          it 'a priori upgraded account stays upgraded' do
            subject = described_class.new(
              base_attributes.merge(upgraded_at: Time.current, account_state: :upgraded)
            )
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('upgraded')
          end

          it 'is able to transition back to upgraded' do
            subject = described_class.new(
              base_attributes.merge(registered_at: Time.current, upgraded_at: Time.current)
            )
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('upgraded')
            expect(subject.creatable?).to be_falsey
            expect(subject.terms_and_conditions_accepted?).to be_truthy
          end
        end

        # NOTE: THIS IS IMPORTANT, we're going to need a database migration, and a change to support multiple mhv_accounts
        # tied to a certain user. Existing accounts might become outdated, but we should retain the record.
        # furthoermore we should create a new account again when user acknowledges, perhaps T&C need to be tied to specific
        # MHV accounts. I can elaborate on this more in discussion.
        # additionally we should log the specific mhv correlation id of the account that was created / upgraded
        # TODO TODO TODO TODO
        context 'without mhv id' do
          it 'a priori registered account changes to no_account' do
            subject = described_class.new(
              base_attributes.merge(registered_at: Time.current, account_state: :registered)
            )
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.creatable?).to be_truthy
            expect(subject.account_state).to eq('no_account')
          end

          it 'a priori upgraded account changes to no_account' do
            subject = described_class.new(
              base_attributes.merge(upgraded_at: Time.current, account_state: :upgraded)
            )
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.creatable?).to be_truthy
            expect(subject.account_state).to eq('no_account')
          end

          it 'is able to transition back to upgraded' do
            subject = described_class.new(
              base_attributes.merge(registered_at: Time.current, upgraded_at: Time.current)
            )
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.terms_and_conditions_accepted?).to be_truthy
            expect(subject.creatable?).to be_truthy
            expect(subject.account_state).to eq('no_account')
          end
        end

        it 'is able to transition back to registered' do
          subject = described_class.new(base_attributes.merge(registered_at: Time.current))
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('registered')
          expect(subject.creatable?).to be_falsey
          expect(subject.terms_and_conditions_accepted?).to be_truthy
        end

        it 'falls back to unknown' do
          subject = described_class.new(base_attributes)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('unknown')
          expect(subject.creatable?).to be_falsey
          expect(subject.terms_and_conditions_accepted?).to be_truthy
        end

        it 'a priori register_failed account changes to unknown' do
          subject = described_class.new(base_attributes.merge(upgraded_at: nil, account_state: :register_failed))
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('unknown')
        end

        it 'a priori upgrade_failed account changes to unknown' do
          subject = described_class.new(base_attributes.merge(upgraded_at: nil, account_state: :upgrade_failed))
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('unknown')
        end
      end

      context 'with terms not accepted' do
        context 'ssn mismatch' do
          let(:user_ssn) { '123456789' }

          it 'is needs_ssn_resolution if ssn is mismatched' do
            subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('needs_ssn_resolution')
            expect(subject.creatable?).to be_falsey
            expect(subject.terms_and_conditions_accepted?).to be_falsey
          end
        end

        context 'not a va patient' do
          let(:vha_facility_ids) { ['999'] }

          it 'is ineligible if not a va patient' do
            subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('needs_va_patient')
            expect(subject.creatable?).to be_falsey
            expect(subject.terms_and_conditions_accepted?).to be_falsey
          end
        end

        context 'preexisting account' do
          let(:mhv_ids) { ['14221465'] }
          let(:base_attributes) { { user_uuid: user.uuid } }

          it 'does not transition to needs_terms_acceptance' do
            subject = described_class.new(base_attributes)
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('existing')
            expect(subject.creatable?).to be_falsey
            expect(subject.terms_and_conditions_accepted?).to be_falsey
          end
        end

        it 'transitions to needs_terms_acceptance' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'upgraded', upgraded_at: Time.current)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
          expect(subject.creatable?).to be_falsey
          expect(subject.terms_and_conditions_accepted?).to be_falsey
        end

        it 'is able to transition back to registered' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'registered', registered_at: Time.current)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
          expect(subject.creatable?).to be_falsey
          expect(subject.terms_and_conditions_accepted?).to be_falsey
        end

        it 'it falls back to unknown' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'unknown')
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
          expect(subject.creatable?).to be_falsey
          expect(subject.terms_and_conditions_accepted?).to be_falsey
        end
      end
    end
  end
end
