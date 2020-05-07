# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/SubjectStub

RSpec.describe Form1010cg::Service do
  let(:subject) { described_class.new build(:caregivers_assistance_claim) }
  let(:default_email_on_mvi_search) { 'no-email@example.com' }
  let(:build_claim_data_for) do
    lambda do |form_subject, &mutations|
      data = {
        'fullName' => {
          'first' => Faker::Name.first_name,
          'last' => Faker::Name.last_name
        },
        'ssnOrTin' => Faker::IDNumber.valid.remove('-'),
        'dateOfBirth' => Faker::Date.between(from: 100.years.ago, to: 18.years.ago).to_s,
        'gender' => %w[M F].sample,
        'address' => {
          'street' => Faker::Address.street_address,
          'city' => Faker::Address.city,
          'state' => Faker::Address.state_abbr,
          'postalCode' => Faker::Address.postcode
        }
      }

      # Required properties for specific form_subjects
      if form_subject == :primaryCaregiver
        data['vetRelationship'] = %w[Father Mother Son Daughter].sample
        data['medicaidEnrolled'] = [true, false].sample
        data['medicareEnrolled'] = [true, false].sample
        data['tricareEnrolled'] = [true, false].sample
        data['champvaEnrolled'] = [true, false].sample
      end

      data['plannedClinic'] = %w[740 568A4 550].sample if form_subject == :veteran

      mutations&.call data

      data
    end
  end

  describe '::new' do
    it 'requires a claim' do
      expect { described_class.new }.to raise_error do |e|
        expect(e).to be_a(ArgumentError)
        expect(e.message).to eq('wrong number of arguments (given 0, expected 1)')
      end
    end

    it 'raises error if claim is invalid' do
      expect { described_class.new(SavedClaim::CaregiversAssistanceClaim.new(form: '{}')) }.to raise_error do |e|
        expect(e).to be_a(Common::Exceptions::ValidationErrors)
        expect(e.errors.size).to eq(2)
        expect(e.errors[0].code).to eq('100')
        expect(e.errors[0].detail).to include("did not contain a required property of 'veteran'")
        expect(e.errors[0].status).to eq('422')
        expect(e.errors[1].detail).to include("did not contain a required property of 'primaryCaregiver'")
        expect(e.errors[1].status).to eq('422')
        expect(e.errors[1].code).to eq('100')
      end
    end

    it 'sets claim' do
      claim = build(:caregivers_assistance_claim)
      service = described_class.new claim

      expect(service.claim).to eq(claim)
    end
  end

  describe '#icn_for' do
    it 'searches MVI for the provided form subject' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for.call(:veteran),
            'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
          }.to_json
        )
      )

      veteran_data = subject.claim.veteran_data

      expected_mvi_search_params = {
        first_name: veteran_data['fullName']['first'],
        middle_name: veteran_data['fullName']['middle'],
        last_name: veteran_data['fullName']['last'],
        birth_date: veteran_data['dateOfBirth'],
        gender: veteran_data['gender'],
        ssn: veteran_data['ssnOrTin'],
        email: default_email_on_mvi_search,
        uuid: be_an_instance_of(String),
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      }

      expect(UserIdentity).to receive(:new).with(
        expected_mvi_search_params
      ).and_return(
        :user_identity
      )

      expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
        :user_identity
      ).and_return(
        double(status: 'OK', profile: double(icn: :ICN_123))
      )

      result = subject.icn_for('veteran')

      expect(result).to eq(:ICN_123)
    end

    it 'sets returns "NOT_FOUND" when profile not found in MVI' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for.call(:veteran),
            'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
          }.to_json
        )
      )

      veteran_data = subject.claim.veteran_data

      expected_mvi_search_params = {
        first_name: veteran_data['fullName']['first'],
        middle_name: veteran_data['fullName']['middle'],
        last_name: veteran_data['fullName']['last'],
        birth_date: veteran_data['dateOfBirth'],
        gender: veteran_data['gender'],
        ssn: veteran_data['ssnOrTin'],
        email: default_email_on_mvi_search,
        uuid: be_an_instance_of(String),
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      }

      expect(UserIdentity).to receive(:new).with(
        expected_mvi_search_params
      ).and_return(
        :user_identity
      )

      expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
        :user_identity
      ).and_raise(
        MVI::Errors::RecordNotFound
      )

      result = subject.icn_for('veteran')

      expect(result).to eq('NOT_FOUND')
    end

    it 'returns a cached responses when called more than once for a given namespace' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for.call(:veteran),
            'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
          }.to_json
        )
      )

      veteran_data = subject.claim.veteran_data
      pc_data = subject.claim.primary_caregiver_data

      expected_mvi_search_params = {
        veteran: {
          first_name: veteran_data['fullName']['first'],
          middle_name: veteran_data['fullName']['middle'],
          last_name: veteran_data['fullName']['last'],
          birth_date: veteran_data['dateOfBirth'],
          gender: veteran_data['gender'],
          ssn: veteran_data['ssnOrTin'],
          email: default_email_on_mvi_search,
          uuid: be_an_instance_of(String),
          loa: {
            current: LOA::THREE,
            highest: LOA::THREE
          }
        },
        primaryCaregiver: {
          first_name: pc_data['fullName']['first'],
          middle_name: pc_data['fullName']['middle'],
          last_name: pc_data['fullName']['last'],
          birth_date: pc_data['dateOfBirth'],
          gender: pc_data['gender'],
          ssn: pc_data['ssnOrTin'],
          email: default_email_on_mvi_search,
          uuid: be_an_instance_of(String),
          loa: {
            current: LOA::THREE,
            highest: LOA::THREE
          }
        }
      }

      expect(UserIdentity).to receive(:new).with(
        expected_mvi_search_params[:veteran]
      ).and_return(
        :veteran_user_identity
      )

      expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
        :veteran_user_identity
      ).and_return(
        double(status: 'OK', profile: double(icn: :CACHED_VALUE))
      )

      expect(UserIdentity).to receive(:new).with(
        expected_mvi_search_params[:primaryCaregiver]
      ).and_return(
        :pc_user_identity
      )

      expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
        :pc_user_identity
      ).and_raise(
        MVI::Errors::RecordNotFound
      )

      3.times do
        expect(subject.icn_for('veteran')).to eq(:CACHED_VALUE)
      end

      3.times do
        expect(subject.icn_for('primaryCaregiver')).to eq('NOT_FOUND')
      end
    end

    context 'when gender is "U"' do
      it 'will search MVI with gender: nil' do
        veteran_data = build_claim_data_for.call(:veteran) do |data|
          data['gender'] = 'U'
        end

        subject = described_class.new(
          build(
            :caregivers_assistance_claim,
            form: {
              'veteran' => veteran_data,
              'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
            }.to_json
          )
        )

        expected_mvi_search_params = {
          first_name: veteran_data['fullName']['first'],
          middle_name: veteran_data['fullName']['middle'],
          last_name: veteran_data['fullName']['last'],
          birth_date: veteran_data['dateOfBirth'],
          gender: nil,
          ssn: veteran_data['ssnOrTin'],
          email: default_email_on_mvi_search,
          uuid: be_an_instance_of(String),
          loa: {
            current: LOA::THREE,
            highest: LOA::THREE
          }
        }

        expect(UserIdentity).to receive(:new).with(
          expected_mvi_search_params
        ).and_return(
          :user_identity
        )

        expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
          :user_identity
        ).and_return(
          double(status: 'OK', profile: double(icn: :ICN_123))
        )

        result = subject.icn_for('veteran')

        expect(result).to eq(:ICN_123)
      end
    end

    context 'when email is provided' do
      it 'will provid that email in the mvi search' do
        veteran_email = 'veteran-email@example.com'
        veteran_data = build_claim_data_for.call(:veteran) do |data|
          data['email'] = veteran_email
        end

        subject = described_class.new(
          build(
            :caregivers_assistance_claim,
            form: {
              'veteran' => veteran_data,
              'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
            }.to_json
          )
        )

        expected_mvi_search_params = {
          first_name: veteran_data['fullName']['first'],
          middle_name: veteran_data['fullName']['middle'],
          last_name: veteran_data['fullName']['last'],
          birth_date: veteran_data['dateOfBirth'],
          gender: veteran_data['gender'],
          ssn: veteran_data['ssnOrTin'],
          email: veteran_email,
          uuid: be_an_instance_of(String),
          loa: {
            current: LOA::THREE,
            highest: LOA::THREE
          }
        }

        expect(UserIdentity).to receive(:new).with(
          expected_mvi_search_params
        ).and_return(
          :user_identity
        )

        expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
          :user_identity
        ).and_return(
          double(status: 'OK', profile: double(icn: :ICN_123))
        )

        result = subject.icn_for('veteran')

        expect(result).to eq(:ICN_123)
      end
    end
  end

  describe '#build_metadata' do
    it 'returns the icn for each subject on the form' do
      %w[veteran primaryCaregiver secondaryCaregiverOne].each_with_index do |form_subject, index|
        return_value = form_subject == 'secondaryCaregiverOne' ? 'NOT_FOUND' : "ICN_#{index}".to_sym
        expect(subject).to receive(:icn_for).with(form_subject).and_return(return_value)
      end

      expect(subject.build_metadata).to eq(
        veteran: {
          icn: :ICN_0
        },
        primaryCaregiver: {
          icn: :ICN_1
        },
        secondaryCaregiverOne: {
          icn: nil # 'NOT_FOUND's should be converted to nil
        }
      )
    end
  end

  describe '#assert_veteran_status' do
    it 'will raise error if veteran\'s icn can not be found' do
      expect(subject).to receive(:icn_for).with('veteran').and_return('NOT_FOUND')
      expect { subject.assert_veteran_status }.to raise_error do |e|
        expect(e).to be_a(Common::Exceptions::ValidationErrors)
        expect(e.errors.size).to eq(1)
        expect(e.errors[0].code).to eq('100')
        expect(e.errors[0].source[:pointer]).to eq('data/attributes/base')
        expect(e.errors[0].detail).to eq('base - Unable to process submission digitally')
        expect(e.errors[0].status).to eq('422')
        expect(e.errors[0].title).to eq('Unable to process submission digitally')
      end
    end

    it 'will not raise error if veteran\'s icn is found' do
      expect(subject).to receive(:icn_for).with('veteran').and_return(:ICN_123)
      expect(subject.assert_veteran_status).to eq(nil)
    end
  end

  describe '#process_claim!' do
    it 'raises error when ICN not found for veteran' do
      expect(subject).to receive(:icn_for).with('veteran').and_return('NOT_FOUND')

      expect { subject.process_claim! }.to raise_error do |e|
        expect(e).to be_a(Common::Exceptions::ValidationErrors)
        expect(e.errors.size).to eq(1)
        expect(e.errors[0].code).to eq('100')
        expect(e.errors[0].source[:pointer]).to eq('data/attributes/base')
        expect(e.errors[0].detail).to eq('base - Unable to process submission digitally')
        expect(e.errors[0].status).to eq('422')
        expect(e.errors[0].title).to eq('Unable to process submission digitally')
      end
    end

    it 'submits the claim with metadata to carma and returns a Form1010cg::Submission' do
      expected = {
        results: {
          carma_case_id: 'aB935000000A9GoCAK',
          submitted_at: DateTime.new
        }
      }

      expect(subject).to receive(:assert_veteran_status).and_return(nil)
      expect(subject).to receive(:build_metadata).and_return(:generated_metadata)
      expect(CARMA::Models::Submission).to receive(:from_claim).with(subject.claim, :generated_metadata) {
        carma_submission = double

        expect(carma_submission).to receive(:submit!) {
          expect(carma_submission).to receive(:carma_case_id).and_return(expected[:results][:carma_case_id])
          expect(carma_submission).to receive(:submitted_at).and_return(expected[:results][:submitted_at])

          carma_submission
        }

        carma_submission
      }

      result = subject.process_claim!

      expect(result).to be_a(Form1010cg::Submission)
      expect(result.carma_case_id).to eq(expected[:results][:carma_case_id])
      expect(result.submitted_at).to eq(expected[:results][:submitted_at])
    end
  end
end

# rubocop:enable RSpec/SubjectStub
