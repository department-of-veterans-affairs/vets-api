# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::UserAccessibleServices, aggregate_failures: true, type: :model do
  let(:user) { build(:user, :loa3) }
  let(:non_evss_user) { build(:user, :loa3, edipi: nil, ssn: nil, participant_id: nil) }
  let(:non_lighthouse_user) { build(:user, :loa3, icn: nil, participant_id: nil) }
  let(:user_services) { Mobile::V0::UserAccessibleServices.new(user) }

  describe '#authorized' do
    describe 'appeals' do
      context 'when user does not have appeals access' do
        let(:user) { build(:user, :loa1) }

        it 'does not include appeals' do
          expect(user_services.authorized).not_to include(:appeals)
        end
      end

      context 'when user does have appeals access' do
        it 'includes appeals' do
          expect(user_services.authorized).to include(:appeals)
        end
      end
    end

    describe 'appointments' do
      it 'is always true' do
        expect(user_services.authorized).to include(:appointments)
      end
    end

    describe 'claims' do
      context 'with mobile_lighthouse_claims flag off' do
        before { Flipper.disable(:mobile_lighthouse_claims) }
        after { Flipper.enable(:mobile_lighthouse_claims) }

        context 'when user does not have evss access' do
          let(:user) { non_evss_user }

          it 'does not include claims' do
            expect(user_services.authorized).not_to include(:claims)
          end
        end

        context 'when user does have evss access' do
          it 'includes claims' do
            expect(user_services.authorized).to include(:claims)
          end
        end
      end

      context 'with mobile_lighthouse_claims flag on' do
        context 'when user does not have lighthouse access' do
          let(:user) { non_lighthouse_user }

          it 'does not include claims' do
            expect(user_services.authorized).not_to include(:claims)
          end
        end

        context 'when user does have lighthouse access' do
          it 'includes claims' do
            expect(user_services.authorized).to include(:claims)
          end
        end
      end
    end

    describe 'decisionLetters' do
      context 'when user does not have bgs access' do
        let(:user) { build(:user, icn: nil, ssn: nil, participant_id: nil) }

        it 'does not include decisionLetters' do
          expect(user_services.authorized).not_to include(:decisionLetters)
        end
      end

      context 'when user does have bgs access' do
        it 'includes decisionLetters' do
          expect(user_services.authorized).to include(:decisionLetters)
        end
      end
    end

    describe 'directDepositBenefits' do
      context 'with mobile_lighthouse_direct_deposit flag off' do
        before { Flipper.disable(:mobile_lighthouse_direct_deposit) }
        after { Flipper.enable(:mobile_lighthouse_direct_deposit) }

        context 'when user does not have evss access' do
          let(:user) { non_evss_user }

          it 'does not include directDepositBenefits' do
            expect(user_services.authorized).not_to include(:directDepositBenefits)
          end
        end

        context 'when user does not have ppiu access' do
          let(:user) { build(:user, :loa1) }

          it 'does not include directDepositBenefits' do
            expect(user_services.authorized).not_to include(:directDepositBenefits)
          end
        end

        context 'when user does have evss and ppiu access' do
          it 'includes directDepositBenefits' do
            expect(user_services.authorized).to include(:directDepositBenefits)
          end
        end
      end

      context 'with mobile_lighthouse_direct_deposit flag on' do
        context 'when user does not have lighthouse access' do
          let(:user) { non_lighthouse_user }

          it 'does not include directDepositBenefits' do
            expect(user_services.authorized).not_to include(:directDepositBenefits)
          end
        end

        context 'when user does have lighthouse access' do
          it 'includes directDepositBenefits' do
            expect(user_services.authorized).to include(:directDepositBenefits)
          end
        end
      end
    end

    describe 'directDepositBenefitsUpdate' do
      context 'with mobile_lighthouse_direct_deposit flag off' do
        before { Flipper.disable(:mobile_lighthouse_direct_deposit) }
        after { Flipper.enable(:mobile_lighthouse_direct_deposit) }

        context 'when user does not have evss access' do
          let(:user) { non_evss_user }

          it 'does not include directDepositBenefitsUpdate' do
            VCR.use_cassette('mobile/payment_information/payment_information') do
              expect(user_services.authorized).not_to include(:directDepositBenefitsUpdate)
            end
          end
        end

        context 'when user does not have ppiu access' do
          let(:user) { build(:user, :loa1) }

          it 'does not include directDepositBenefitsUpdate' do
            VCR.use_cassette('mobile/payment_information/payment_information') do
              expect(user_services.authorized).not_to include(:directDepositBenefitsUpdate)
            end
          end
        end

        context 'when user does not have ppiu access_update' do
          it 'does not include directDepositBenefitsUpdate' do
            VCR.use_cassette('mobile/payment_information/payment_information_unauthorized_to_update') do
              expect(user_services.authorized).not_to include(:directDepositBenefitsUpdate)
            end
          end
        end

        context 'when ppiu access_update upstream request fails' do
          it 'does not include directDepositBenefitsUpdate' do
            VCR.use_cassette('mobile/payment_information/service_error_500') do
              expect(user_services.authorized).not_to include(:directDepositBenefitsUpdate)
            end
          end
        end

        context 'when user does have evss and access as well as ppiu access_update' do
          it 'includes directDepositBenefitsUpdate' do
            VCR.use_cassette('mobile/payment_information/payment_information') do
              expect(user_services.authorized).to include(:directDepositBenefitsUpdate)
            end
          end
        end
      end

      context 'with mobile_lighthouse_direct_deposit flag on' do
        context 'when user does not have lighthouse access' do
          let(:user) { non_lighthouse_user }

          it 'does not include directDepositBenefitsUpdate' do
            expect(user_services.authorized).not_to include(:directDepositBenefitsUpdate)
          end
        end

        context 'when user does have lighthouse access' do
          it 'includes directDepositBenefitsUpdate' do
            expect(user_services.authorized).to include(:directDepositBenefitsUpdate)
          end
        end
      end
    end

    describe 'disabilityRating' do
      context 'with mobile_lighthouse_disability_ratings flag off' do
        before { Flipper.disable(:mobile_lighthouse_disability_ratings) }
        after { Flipper.enable(:mobile_lighthouse_disability_ratings) }

        context 'when user does not have evss access' do
          let(:user) { non_evss_user }

          it 'does not include disabilityRating' do
            expect(user_services.authorized).not_to include(:disabilityRating)
          end
        end

        context 'when user does have evss access' do
          it 'includes disabilityRating' do
            expect(user_services.authorized).to include(:disabilityRating)
          end
        end
      end

      context 'with mobile_lighthouse_disability_ratings flag on' do
        context 'when user does not have lighthouse access' do
          let(:user) { non_lighthouse_user }

          it 'does not include disabilityRating' do
            expect(user_services.authorized).not_to include(:disabilityRating)
          end
        end

        context 'when user does have lighthouse access' do
          it 'includes disabilityRating' do
            expect(user_services.authorized).to include(:disabilityRating)
          end
        end
      end
    end

    describe 'genderIdentity and preferredName' do
      context 'when user does not have demographics access' do
        let(:user) { build(:user, :loa3, idme_uuid: nil, logingov_uuid: nil) }

        it 'does not include preferredName and genderIdentity' do
          expect(user_services.authorized).not_to include(:preferredName)
          expect(user_services.authorized).not_to include(:genderIdentity)
        end
      end

      context 'when user does not have mpi queryable access' do
        let(:user) { build(:user, :loa3, icn: nil, ssn: nil) }

        it 'does not include preferredName and genderIdentity' do
          expect(user_services.authorized).not_to include(:preferredName)
          expect(user_services.authorized).not_to include(:genderIdentity)
        end
      end

      context 'when user does have demographics and mpi queryable access' do
        it 'includes preferredName and genderIdentity' do
          expect(user_services.authorized).to include(:preferredName)
          expect(user_services.authorized).to include(:genderIdentity)
        end
      end
    end

    describe 'lettersAndDocuments' do
      context 'with mobile_lighthouse_letters flag off' do
        before { Flipper.disable(:mobile_lighthouse_letters) }
        after { Flipper.enable(:mobile_lighthouse_letters) }

        context 'when user does not have evss access' do
          let(:user) { non_evss_user }

          it 'does not include lettersAndDocuments' do
            expect(user_services.authorized).not_to include(:lettersAndDocuments)
          end
        end

        context 'when user does have evss access' do
          it 'includes lettersAndDocuments' do
            expect(user_services.authorized).to include(:lettersAndDocuments)
          end
        end
      end

      context 'with mobile_lighthouse_letters flag on' do
        context 'when user does not have lighthouse access' do
          let(:user) { non_lighthouse_user }

          it 'does not include lettersAndDocuments' do
            expect(user_services.authorized).not_to include(:lettersAndDocuments)
          end
        end

        context 'when user does have lighthouse access' do
          it 'includes lettersAndDocuments' do
            expect(user_services.authorized).to include(:lettersAndDocuments)
          end
        end
      end
    end

    describe 'militaryServiceHistory' do
      context 'when user does not have vet360 update access' do
        let(:user) { build(:user, :loa3, edipi: nil) }

        it 'does not include militaryServiceHistory' do
          expect(user_services.authorized).not_to include(:militaryServiceHistory)
        end
      end

      context 'when user does have vet360 update access' do
        it 'includes militaryServiceHistory' do
          expect(user_services.authorized).to include(:militaryServiceHistory)
        end
      end
    end

    describe 'paymentHistory' do
      context 'when user does not have bgs access' do
        let(:user) { build(:user, :loa3, participant_id: nil) }

        it 'does not include paymentHistory' do
          expect(user_services.authorized).not_to include(:paymentHistory)
        end
      end

      context 'when user does have bgs access' do
        it 'includes paymentHistory' do
          expect(user_services.authorized).to include(:paymentHistory)
        end
      end
    end

    describe 'prescriptions' do
      context 'when user does not have mhv_prescriptions access' do
        it 'does not include prescriptions' do
          expect(user_services.authorized).not_to include(:prescriptions)
        end
      end

      context 'when user does have mhv_prescriptions access' do
        let(:user) { build(:user, :mhv) }

        it 'includes prescriptions' do
          expect(user_services.authorized).to include(:prescriptions)
        end
      end
    end

    describe 'scheduleAppointments' do
      context 'when user does not have schedule_appointment access' do
        let(:user) { build(:user, :loa1) }

        it 'does not include scheduleAppointments' do
          expect(user_services.authorized).not_to include(:scheduleAppointments)
        end
      end

      context 'when user does have schedule_appointment access' do
        let(:user) { build(:user, :mhv) } # must have mhv facility ids

        it 'includes scheduleAppointments' do
          expect(user_services.authorized).to include(:scheduleAppointments)
        end
      end
    end

    describe 'secureMessaging' do
      context 'when user does not have mhv_messaging access' do
        it 'does not include secureMessaging' do
          expect(user_services.authorized).not_to include(:secureMessaging)
        end
      end

      context 'when user does have mhv_messaging access' do
        let(:user) { build(:user, :mhv) }

        it 'includes secureMessaging' do
          expect(user_services.authorized).to include(:secureMessaging)
        end
      end
    end

    describe 'userProfileUpdate' do
      context 'when user does not have vet360 access' do
        let(:user) { build(:user, :loa3, vet360_id: nil) }

        it 'does not include userProfileUpdate' do
          expect(user_services.authorized).not_to include(:userProfileUpdate)
        end
      end

      context 'when user does have vet360 access' do
        it 'includes userProfileUpdate' do
          expect(user_services.authorized).to include(:userProfileUpdate)
        end
      end
    end
  end

  describe '#available' do
    it 'returns a list of all services' do
      expect(user_services.available).to eq(
        %i[
          appeals
          appointments
          claims
          decisionLetters
          directDepositBenefits
          directDepositBenefitsUpdate
          disabilityRating
          genderIdentity
          lettersAndDocuments
          militaryServiceHistory
          paymentHistory
          preferredName
          prescriptions
          scheduleAppointments
          secureMessaging
          userProfileUpdate
        ]
      )
    end
  end
end
