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
        },
        'primaryPhoneNumber' => Faker::Number.number(digits: 10).to_s
      }

      # Required properties for :primaryCaregiver
      if form_subject == :primaryCaregiver
        data['vetRelationship'] = 'Daughter'
        data['medicaidEnrolled'] = true
        data['medicareEnrolled'] = false
        data['tricareEnrolled'] = false
        data['champvaEnrolled'] = false
      end

      # Required property for :veteran
      data['plannedClinic'] = '568A4' if form_subject == :veteran

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
      ).and_return(
        double(status: 'NOT_FOUND', error: double)
      )

      result = subject.icn_for('veteran')

      expect(result).to eq('NOT_FOUND')
    end

    it 'returns a cached responses when called more than once for a given subject' do
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
      ).and_return(
        double(status: 'NOT_FOUND', error: double)
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

  describe '#is_veteran' do
    it 'returns false if the icn for the for the subject is "NOT_FOUND"' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for.call(:veteran),
            'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
          }.to_json
        )
      )

      expect(subject).to receive(:icn_for).with('veteran').and_return('NOT_FOUND')
      expect_any_instance_of(EMIS::VeteranStatusService).not_to receive(:get_veteran_status)

      expect(subject.is_veteran('veteran')).to eq(false)
    end

    describe 'searches eMIS and' do
      context 'when title38_status_code is "V1"' do
        it 'returns true' do
          subject = described_class.new(
            build(
              :caregivers_assistance_claim,
              form: {
                'veteran' => build_claim_data_for.call(:veteran),
                'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
              }.to_json
            )
          )

          expected_icn = :ICN_123
          emis_response = double(
            error?: false,
            items: [
              double(
                title38_status_code: 'V1'
              )
            ]
          )

          expect(subject).to receive(:icn_for).with('veteran').and_return(expected_icn)
          expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status).with(
            icn: expected_icn
          ).and_return(
            emis_response
          )

          expect(subject.is_veteran('veteran')).to eq(true)
        end
      end

      context 'when title38_status_code is not "V1"' do
        it 'returns false' do
          subject = described_class.new(
            build(
              :caregivers_assistance_claim,
              form: {
                'veteran' => build_claim_data_for.call(:veteran),
                'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
              }.to_json
            )
          )

          expected_icn = :ICN_123
          emis_response = double(
            error?: false,
            items: [
              double(
                title38_status_code: 'V4'
              )
            ]
          )

          expect(subject).to receive(:icn_for).with('veteran').and_return(expected_icn)
          expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status).with(
            icn: expected_icn
          ).and_return(
            emis_response
          )

          expect(subject.is_veteran('veteran')).to eq(false)
        end
      end

      context 'when title38_status_code is not present' do
        it 'returns false' do
          subject = described_class.new(
            build(
              :caregivers_assistance_claim,
              form: {
                'veteran' => build_claim_data_for.call(:veteran),
                'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
              }.to_json
            )
          )

          expected_icn = :ICN_123
          emis_response = double(
            error?: false,
            items: []
          )

          expect(subject).to receive(:icn_for).with('veteran').and_return(expected_icn)
          expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status).with(
            icn: expected_icn
          ).and_return(
            emis_response
          )

          expect(subject.is_veteran('veteran')).to eq(false)
        end
      end

      context 'when the search fails' do
        it 'raises the error found in the MVI response' do
          subject = described_class.new(
            build(
              :caregivers_assistance_claim,
              form: {
                'veteran' => build_claim_data_for.call(:veteran),
                'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
              }.to_json
            )
          )

          expected_icn = :ICN_123
          emis_response = double(
            error?: true,
            error: Common::Client::Errors::HTTPError.new('BadRequest', 400, nil)
          )

          expect(subject).to receive(:icn_for).with('veteran').and_return(expected_icn)
          expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status).with(
            icn: expected_icn
          ).and_return(
            emis_response
          )

          expect { subject.is_veteran('veteran') }.to raise_error do |e|
            expect(e).to be_a(Common::Client::Errors::HTTPError)
          end
        end
      end
    end

    it 'returns a cached responses when called more than once for a given subject' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for.call(:veteran),
            'primaryCaregiver' => build_claim_data_for.call(:primaryCaregiver)
          }.to_json
        )
      )

      # Only two calls should be made to eMIS for the six calls of :is_veteran below
      2.times do |index|
        expected_form_subject = index.zero? ? 'veteran' : 'primaryCaregiver'
        expected_icn = "ICN_#{index}".to_sym

        expect(subject).to receive(:icn_for).with(expected_form_subject).and_return(expected_icn)

        emis_service = double
        emis_response_title38_value = index.zero? ? 'V1' : 'V4'
        emis_response = double(
          error?: false,
          items: [
            double(
              title38_status_code: emis_response_title38_value
            )
          ]
        )

        expect(EMIS::VeteranStatusService).to receive(:new).with(no_args).and_return(emis_service)
        expect(emis_service).to receive(:get_veteran_status).with(
          icn: expected_icn
        ).and_return(
          emis_response
        )
      end

      3.times do
        expect(subject.is_veteran('veteran')).to eq(true)
        expect(subject.is_veteran('primaryCaregiver')).to eq(false)
      end
    end
  end

  describe '#build_metadata' do
    it 'returns the icn for each subject on the form and the veteran\'s status' do
      %w[veteran primaryCaregiver secondaryCaregiverOne].each_with_index do |form_subject, index|
        return_value = form_subject == 'secondaryCaregiverOne' ? 'NOT_FOUND' : "ICN_#{index}".to_sym
        expect(subject).to receive(:icn_for).with(form_subject).and_return(return_value)
      end

      expect(subject).not_to receive(:is_veteran)

      expect(subject.build_metadata).to eq(
        veteran: {
          icn: :ICN_0,
          is_veteran: false
        },
        primary_caregiver: {
          icn: :ICN_1
        },
        secondary_caregiver_one: {
          # Note that NOT_FOUND is converted to nil
          icn: nil
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
      expect(subject).not_to receive(:is_veteran)

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
