# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Service do
  let(:default_email_on_mvi_search) { 'no-email@example.com' }

  describe '#fetch_and_build_metadata' do
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
        data['vetRelationship'] = %w[Father Mother Son Daughter].sample if form_subject == :primaryCaregiver
        data['plannedClinic'] = %w[740 568A4 550].sample if form_subject == :veteran

        mutations&.call data

        data
      end
    end

    context 'with no email provided' do
      it 'searches MVI with email: "no-email@example.com"' do
        pc_email = 'pc@example.com'

        veteran_data = build_claim_data_for.call(:veteran)

        pc_data = build_claim_data_for.call(:primaryCaregiver) do |data|
          data['email'] = pc_email
        end

        claim = double(
          parsed_form: {
            'veteran' => veteran_data,
            'primaryCaregiver' => pc_data
          }
        )

        [veteran_data, pc_data].each_with_index do |subjects_data, int|
          user_identity_key = "user_identity_#{int}".to_sym

          expected_mvi_search_params = {
            first_name: subjects_data['fullName']['first'],
            middle_name: subjects_data['fullName']['middle'],
            last_name: subjects_data['fullName']['last'],
            birth_date: subjects_data['dateOfBirth'],
            gender: subjects_data['gender'],
            ssn: subjects_data['ssnOrTin'],
            email: int.zero? ? default_email_on_mvi_search : pc_email,
            uuid: be_an_instance_of(String),
            loa: {
              current: LOA::THREE,
              highest: LOA::THREE
            }
          }

          expect(UserIdentity).to receive(:new).with(
            expected_mvi_search_params
          ).and_return(
            user_identity_key
          )

          expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
            user_identity_key
          ).and_return(
            double(status: 'OK', profile: double(icn: "ICN_#{int}"))
          )
        end

        subject.fetch_and_build_metadata(claim)
      end
    end

    context 'with gender set as "U"' do
      it 'searches mvi with gender: nil' do
        veteran_data = build_claim_data_for.call(:veteran) do |data|
          data['gender'] = 'U'
        end

        pc_data = build_claim_data_for.call(:primaryCaregiver) do |data|
          data['gender'] = 'U'
        end

        claim = double(
          parsed_form: {
            'veteran' => veteran_data,
            'primaryCaregiver' => pc_data
          }
        )

        [veteran_data, pc_data].each_with_index do |subjects_data, int|
          user_identity_key = "user_identity_#{int}".to_sym

          expected_mvi_search_params = {
            first_name: subjects_data['fullName']['first'],
            middle_name: subjects_data['fullName']['middle'],
            last_name: subjects_data['fullName']['last'],
            birth_date: subjects_data['dateOfBirth'],
            gender: nil,
            ssn: subjects_data['ssnOrTin'],
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
            user_identity_key
          )

          expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
            user_identity_key
          ).and_return(
            double(status: 'OK', profile: double(icn: "ICN_#{int}"))
          )
        end

        subject.fetch_and_build_metadata(claim)
      end
    end

    context 'when veteran is not found' do
      it 'raises an error' do
        veteran_data = build_claim_data_for.call(:veteran)
        pc_data = build_claim_data_for.call(:primaryCaregiver)

        claim = build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => veteran_data,
            'primaryCaregiver' => pc_data
          }.to_json
        )

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
          :user_identity_1
        )

        expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
          :user_identity_1
        ).and_raise(
          MVI::Errors::RecordNotFound
        )

        # make sure other people on form aren't searched in MVI after veteran search fails
        expect(UserIdentity).not_to receive(:new).with(expected_mvi_search_params[:primaryCaregiver])
        expect_any_instance_of(MVI::Service).not_to receive(:find_profile).with(:user_identity_2)

        expect { subject.fetch_and_build_metadata(claim) }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::ValidationErrors)
          expect(e.errors.size).to eq(1)
          expect(e.errors[0].code).to eq('100')
          expect(e.errors[0].detail).to eq('base - Veteran could not be found in the VA\'s system')
          expect(e.errors[0].status).to eq('422')
          expect(e.errors[0].title).to eq('Veteran could not be found in the VA\'s system')
        end
      end
    end

    context 'when other subjects are found' do
      it 'returns their icns' do
        subjects_data = [
          build_claim_data_for.call(:veteran),
          build_claim_data_for.call(:primaryCaregiver),
          build_claim_data_for.call(:secondaryCaregiverOne),
          build_claim_data_for.call(:secondaryCaregiverTwo)
        ]

        claim = build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => subjects_data[0],
            'primaryCaregiver' => subjects_data[1],
            'secondaryCaregiverOne' => subjects_data[2],
            'secondaryCaregiverTwo' => subjects_data[3]
          }.to_json
        )

        subjects_data.each_with_index do |subject_data, int|
          user_identity_key = "user_identity_#{int}".to_sym

          expected_mvi_search_params = {
            first_name: subject_data['fullName']['first'],
            middle_name: subject_data['fullName']['middle'],
            last_name: subject_data['fullName']['last'],
            birth_date: subject_data['dateOfBirth'],
            gender: subject_data['gender'],
            ssn: subject_data['ssnOrTin'],
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
            user_identity_key
          )

          expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
            user_identity_key
          ).and_return(
            double(status: 'OK', profile: double(icn: "ICN_#{int}"))
          )
        end

        result = subject.fetch_and_build_metadata(claim)

        expect(result).to eq(
          veteran: {
            icn: 'ICN_0'
          },
          primaryCaregiver: {
            icn: 'ICN_1'
          },
          secondaryCaregiverOne: {
            icn: 'ICN_2'
          },
          secondaryCaregiverTwo: {
            icn: 'ICN_3'
          }
        )
      end
    end

    context 'when other subjects are not found' do
      it 'does not return their icns' do
        subjects_data = [
          build_claim_data_for.call(:veteran),
          build_claim_data_for.call(:primaryCaregiver),
          build_claim_data_for.call(:secondaryCaregiverOne),
          build_claim_data_for.call(:secondaryCaregiverTwo)
        ]

        claim = build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => subjects_data[0],
            'primaryCaregiver' => subjects_data[1],
            'secondaryCaregiverOne' => subjects_data[2],
            'secondaryCaregiverTwo' => subjects_data[3]
          }.to_json
        )

        subjects_data.each_with_index do |subject_data, int|
          user_identity_key = "user_identity_#{int}".to_sym
          expected_mvi_search_params = {
            first_name: subject_data['fullName']['first'],
            middle_name: subject_data['fullName']['middle'],
            last_name: subject_data['fullName']['last'],
            birth_date: subject_data['dateOfBirth'],
            gender: subject_data['gender'],
            ssn: subject_data['ssnOrTin'],
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
            user_identity_key
          )

          mvi_result = expect_any_instance_of(MVI::Service).to receive(:find_profile).with(
            user_identity_key
          )

          if int > 0
            mvi_result.and_raise(MVI::Errors::RecordNotFound)
          else
            mvi_result.and_return(
              double(status: 'OK', profile: double(icn: "ICN_#{int}"))
            )
          end
        end

        expect(subject.fetch_and_build_metadata(claim)).to eq(
          veteran: {
            icn: 'ICN_0'
          }
        )
      end
    end
  end

  describe '#submit!' do
    it 'will raise a ValidationErrors when the provided claim is invalid' do
      invalid_claim_data = { form: '{}' }

      expect(CARMA::Models::Submission).not_to receive(:new)

      expect { subject.submit_claim!(invalid_claim_data) }.to raise_error do |e|
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

    it 'will return a Form1010cg::Submission with metadata' do
      claim_data        = double
      claim             = double
      carma_submission  = double

      expected = {
        results: {
          carma_case_id: 'aB935000000A9GoCAK',
          submitted_at: DateTime.new
        }
      }

      expect(SavedClaim::CaregiversAssistanceClaim).to receive(:new).with(
        claim_data
      ).and_return(
        claim
      )

      expect(claim).to receive(:valid?).and_return(true)

      expect(CARMA::Models::Submission).to receive(:from_claim).with(
        claim
      ).and_return(
        carma_submission
      )

      # rubocop:disable RSpec/SubjectStub
      expect(subject).to receive(:fetch_and_build_metadata).with(claim).and_return(:generated_metadata)
      # rubocop:enable RSpec/SubjectStub

      expect(carma_submission).to receive(:metadata=).with(:generated_metadata)
      expect(carma_submission).to receive(:submit!) {
        expect(carma_submission).to receive(:carma_case_id).and_return(expected[:results][:carma_case_id])
        expect(carma_submission).to receive(:submitted_at).and_return(expected[:results][:submitted_at])
      }

      submission = subject.submit_claim!(claim_data)

      expect(submission).to be_an_instance_of(Form1010cg::Submission)
      expect(submission.carma_case_id).to eq(expected[:results][:carma_case_id])
      expect(submission.submitted_at).to eq(expected[:results][:submitted_at])
    end
  end
end
