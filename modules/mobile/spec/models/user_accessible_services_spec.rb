# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::UserAccessibleServices, :aggregate_failures, type: :model do
  let(:user) { build(:user, :loa3, vha_facility_ids: [402, 555]) }
  let(:non_lighthouse_user) { build(:user, :loa3, icn: nil, participant_id: nil) }
  let(:user_services) { Mobile::V0::UserAccessibleServices.new(user) }

  describe '#authorized' do
    describe 'appeals' do
      context 'when user does not have appeals access' do
        let(:user) { build(:user, :loa1) }

        it 'is false' do
          expect(user_services.service_auth_map[:appeals]).to be(false)
        end
      end

      context 'when user does have appeals access' do
        it 'is true' do
          expect(user_services.service_auth_map[:appeals]).to be_truthy
        end
      end
    end

    describe 'appointments' do
      context 'when user does not have vaos access' do
        let(:user) { build(:user, :loa1, vha_facility_ids: [402, 555]) }

        it 'is false' do
          expect(user_services.service_auth_map[:appointments]).to be(false)
        end
      end

      context 'when user does not have an icn' do
        let!(:user) { build(:user, :loa3, icn: nil, vha_facility_ids: [402, 555]) }

        it 'is false' do
          expect(user_services.service_auth_map[:appointments]).to be(false)
        end
      end

      context 'when user has VAOS access and an ICN but no facilities' do
        let!(:user) { build(:user, :loa3, vha_facility_ids: []) }

        it 'is false' do
          expect(user_services.service_auth_map[:appointments]).to be(false)
        end
      end

      context 'when user has an icn and vaos access' do
        it 'is true' do
          expect(user_services.service_auth_map[:appointments]).to be_truthy
        end
      end
    end

    describe 'claims' do
      context 'when user does not have lighthouse access' do
        let(:user) { non_lighthouse_user }

        it 'is false' do
          expect(user_services.service_auth_map[:claims]).to be(false)
        end
      end

      context 'when user does have lighthouse access' do
        it 'is true' do
          expect(user_services.service_auth_map[:claims]).to be_truthy
        end
      end
    end

    describe 'decisionLetters' do
      context 'when user does not have bgs access' do
        let(:user) { build(:user, icn: nil, ssn: nil, participant_id: nil) }

        it 'is false' do
          expect(user_services.service_auth_map[:decisionLetters]).to be(false)
        end
      end

      context 'when user does have bgs access' do
        it 'is true' do
          expect(user_services.service_auth_map[:decisionLetters]).to be_truthy
        end
      end
    end

    describe 'directDepositBenefits' do
      context 'when user does not have lighthouse access' do
        let(:user) { non_lighthouse_user }

        it 'is false' do
          expect(user_services.service_auth_map[:directDepositBenefits]).to be(false)
        end
      end

      context 'when user does have lighthouse access' do
        it 'is true' do
          expect(user_services.service_auth_map[:directDepositBenefits]).to be_truthy
        end
      end
    end

    describe 'directDepositBenefitsUpdate' do
      context 'when user does not have lighthouse access' do
        let(:user) { non_lighthouse_user }

        it 'is false' do
          expect(user_services.service_auth_map[:directDepositBenefitsUpdate]).to be(false)
        end
      end

      context 'when user does have lighthouse access' do
        it 'is true' do
          expect(user_services.service_auth_map[:directDepositBenefitsUpdate]).to be_truthy
        end
      end
    end

    describe 'disabilityRating' do
      context 'when a user does not have lighthouse access' do
        let(:user) { non_lighthouse_user }

        it 'is false' do
          expect(user_services.service_auth_map[:disabilityRating]).to be(false)
        end
      end

      context 'when user does have lighthouse access' do
        it 'is true' do
          expect(user_services.service_auth_map[:disabilityRating]).to be_truthy
        end
      end
    end

    describe 'genderIdentity and preferredName' do
      context 'when user does not have demographics access' do
        let(:user) do
          build(:user, :loa3, uuid: 'some-uuid', idme_uuid: nil, logingov_uuid: nil, user_verification: nil)
        end

        it 'is false' do
          expect(user_services.service_auth_map[:preferredName]).to be(false)
          expect(user_services.service_auth_map[:genderIdentity]).to be(false)
        end
      end

      context 'when user does not have mpi queryable access' do
        let(:user) { build(:user, :loa3, icn: nil, ssn: nil) }

        it 'is false' do
          expect(user_services.service_auth_map[:preferredName]).to be(false)
          expect(user_services.service_auth_map[:genderIdentity]).to be(false)
        end
      end

      context 'when user does have demographics and mpi queryable access' do
        it 'is true' do
          expect(user_services.service_auth_map[:preferredName]).to be_truthy
          expect(user_services.service_auth_map[:genderIdentity]).to be_truthy
        end
      end
    end

    describe 'lettersAndDocuments' do
      context 'when user does not have lighthouse access' do
        let(:user) { non_lighthouse_user }

        it 's false' do
          expect(user_services.service_auth_map[:lettersAndDocuments]).to be(false)
        end
      end

      context 'when user does have lighthouse access' do
        it 'is true' do
          expect(user_services.service_auth_map[:lettersAndDocuments]).to be_truthy
        end
      end
    end

    describe 'militaryServiceHistory' do
      context 'when user does not have vet360 update access' do
        let(:user) { build(:user, :loa3, edipi: nil) }

        it 'is false' do
          expect(user_services.service_auth_map[:militaryServiceHistory]).to be(false)
        end
      end

      context 'when user does have vet360 update access' do
        it 'is true' do
          expect(user_services.service_auth_map[:militaryServiceHistory]).to be_truthy
        end
      end
    end

    describe 'paymentHistory' do
      context 'when user does not have bgs access' do
        let(:user) { build(:user, :loa3, participant_id: nil) }

        it 'is false' do
          expect(user_services.service_auth_map[:paymentHistory]).to be(false)
        end
      end

      context 'when user does have bgs access' do
        it 'is true' do
          expect(user_services.service_auth_map[:paymentHistory]).to be_truthy
        end
      end
    end

    describe 'prescriptions' do
      context 'when user does not have mhv_prescriptions access' do
        it 'is false' do
          expect(user_services.service_auth_map[:prescriptions]).to be(false)
        end
      end

      context 'when user does have mhv_prescriptions access' do
        let(:user) { build(:user, :mhv) }

        before do
          allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: true))
        end

        it 'is true' do
          expect(user_services.service_auth_map[:prescriptions]).to be_truthy
        end
      end
    end

    describe 'scheduleAppointments' do
      context 'when user does not have schedule_appointment access' do
        let(:user) { build(:user, :loa1) }

        it 'is false' do
          expect(user_services.service_auth_map[:scheduleAppointments]).to be(false)
        end
      end

      context 'when user does have schedule_appointment access' do
        let(:user) { build(:user, :mhv) } # must have mhv facility ids

        it 'is true' do
          expect(user_services.service_auth_map[:scheduleAppointments]).to be_truthy
        end
      end
    end

    describe 'secureMessaging' do
      before { Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z')) }
      after { Timecop.return }

      context 'when user does not have mhv_messaging access' do
        it 'is false' do
          expect(user_services.service_auth_map[:secureMessaging]).to be(false)
        end
      end

      context 'when user does have mhv_messaging access' do
        it 'is true' do
          VCR.use_cassette('sm_client/session') do
            expect(user_services.service_auth_map[:secureMessaging]).to be_truthy
          end
        end
      end
    end

    describe 'userProfileUpdate' do
      context 'when user does not have vet360 access' do
        let(:user) { build(:user, :loa3, vet360_id: nil, icn: nil) }

        it 'is false' do
          expect(user_services.service_auth_map[:userProfileUpdate]).to be(false)
        end
      end

      context 'when user does have vet360 access' do
        it 'is true' do
          expect(user_services.service_auth_map[:userProfileUpdate]).to be_truthy
        end
      end
    end
  end

  describe '#min_version?' do
    let(:user_services) { Mobile::V0::UserAccessibleServices.new(user, request) }
    let(:request) { double('request', headers: { 'App-Version' => app_version }) }

    before do
      allow(Settings.vahb.version_requirement).to receive(:allergies_oracle_health).and_return('3.0.0')
    end

    context 'when app version meets minimum requirement' do
      let(:app_version) { '5.0.0' }

      it 'returns true' do
        expect(user_services.send(:min_version?, :allergies_oracle_health)).to be(true)
      end
    end

    context 'when app version does not meet minimum requirement' do
      let(:app_version) { '1.0.0' }

      it 'returns false' do
        expect(user_services.send(:min_version?, :allergies_oracle_health)).to be(false)
      end
    end

    context 'when app version is missing' do
      let(:app_version) { nil }

      it 'returns false' do
        expect(user_services.send(:min_version?, :allergies_oracle_health)).to be(false)
      end
    end

    context 'when app version is malformed' do
      let(:app_version) { 'invalid.version.string' }

      it 'returns false' do
        expect(user_services.send(:min_version?, :allergies_oracle_health)).to be(false)
      end
    end

    context 'when feature is not configured in settings' do
      let(:app_version) { '5.0.0' }

      it 'returns false' do
        expect(user_services.send(:min_version?, :non_existent_feature)).to be(false)
      end
    end
  end
end
