# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/data_translation_all_claim'

describe EVSS::DisabilityCompensationForm::DataTranslationAllClaim do
  let(:form_content) { { 'form526' => {} } }
  let(:evss_json) { File.read 'spec/support/disability_compensation_form/all_claims_evss_submission.json' }
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  subject { described_class.new(user, form_content) }

  describe '#translate' do
    before do
      create(:in_progress_form, form_id: VA526ez::FORM_ID, user_uuid: user.uuid)
    end

    let(:form_content) do
      JSON.parse(File.read('spec/support/disability_compensation_form/all_claims_fe_submission.json'))
    end

    it 'should return correctly formatted json to send to EVSS' do
      VCR.use_cassette('evss/ppiu/payment_information') do
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          VCR.use_cassette('emis/get_military_service_episodes/valid', allow_playback_repeats: true) do
            expect(JSON.parse(subject.translate)).to eq JSON.parse(evss_json)
          end
        end
      end
    end
  end

  describe '#translate_banking_info' do
    context 'when provided banking info' do
      let(:form_content) do
        {
          'form526' => {
            'bankName' => 'test',
            'bankAccountType' => 'checking',
            'bankAccountNumber' => '1234567890',
            'bankRoutingNumber' => '0987654321'
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_banking_info)).to eq 'directDeposit' => {
          'accountType' => 'CHECKING',
          'accountNumber' => '1234567890',
          'routingNumber' => '0987654321',
          'bankName' => 'test'
        }
      end
    end

    context 'when not provided banking info' do
      context 'and the PPIU service has the account info' do
        it 'should gather the banking info from the PPIU service' do
          VCR.use_cassette('evss/ppiu/payment_information') do
            expect(subject.send(:translate_banking_info)).to eq 'directDeposit' => {
              'accountType' => 'CHECKING',
              'accountNumber' => '9876543211234',
              'routingNumber' => '042102115',
              'bankName' => 'Comerica'
            }
          end
        end
      end

      context 'and the PPIU service does not have the account info' do
        let(:response) do
          OpenStruct.new(
            get_payment_information: OpenStruct.new(
              responses: [OpenStruct.new(payment_account: nil)]
            )
          )
        end

        it 'should not set payment information' do
          expect(EVSS::PPIU::Service).to receive(:new).once.and_return(response)
          expect(subject.send(:translate_banking_info)).to eq({})
        end
      end
    end
  end

  describe '#translate_service_pay' do
    context 'when no relevant data is provided' do
      it 'should return an empty hash' do
        expect(subject.send(:translate_service_pay)).to eq({})
      end
    end

    context 'when provided benefit waving data' do
      let(:form_content) do
        {
          'form526' => {
            'waiveTrainingPay' => true,
            'waiveRetirementPay' => true
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_service_pay)).to eq 'servicePay' => {
          'waiveVABenefitsToRetainTrainingPay' => true,
          'waiveVABenefitsToRetainRetiredPay' => true
        }
      end
    end

    context 'when provided military retired data' do
      let(:form_content) { { 'form526' => { 'militaryRetiredPayBranch' => 'Air Force' } } }
      it 'should translate the data correctly' do
        expect(subject.send(:translate_service_pay)).to eq 'servicePay' => {
          'militaryRetiredPay' => {
            'receiving' => true,
            'payment' => {
              'serviceBranch' => 'Air Force'
            }
          }
        }
      end
    end

    context 'when provided separation pay data' do
      let(:form_content) do
        {
          'form526' => {
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-01-31'
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_service_pay)).to eq 'servicePay' => {
          'separationPay' => {
            'received' => true,
            'payment' => {
              'serviceBranch' => 'Air Force'
            },
            'receivedDate' => {
              'day' => '31',
              'month' => '1',
              'year' => '2018'
            }
          }
        }
      end
    end
  end

  describe '#translate_service_info' do
    context 'when provided combat zone data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => []
            },
            'servedInCombatZonePost911' => true
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [],
          'servedInCombatZone' => true
        }
      end
    end

    context 'when provided service period data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '1990-01-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            }
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '1990-01-02'
            }
          ]
        }
      end
    end

    context 'when provided confinements data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => []
            },
            'confinements' => [
              {
                'from' => '1984-01-31',
                'to' => '1985-02-01'
              }
            ]
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [],
          'confinements' => [
            {
              'confinementBeginDate' => '1984-01-31',
              'confinementEndDate' => '1985-02-01'
            }
          ]
        }
      end
    end

    context 'when provided national guard service data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [],
              'reservesNationalGuardService' => {
                'obligationTermOfServiceDateRange' => {
                  'from' => '2000-01-04',
                  'to' => '2004-01-04'
                },
                'title10Activation' => {
                  'anticipatedSeparationDate' => '2020-01-01',
                  'title10ActivationDate' => '1999-03-04'
                },
                'unitName' => 'Seal Team Six',
                'unitPhone' => '1231231231'
              }
            },
            'waiveTrainingPay' => true
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [],
          'reservesNationalGuardService' => {
            'obligationTermOfServiceFromDate' => '2000-01-04',
            'obligationTermOfServiceToDate' => '2004-01-04',
            'receivingInactiveDutyTrainingPay' => true,
            'title10Activation' => {
              'anticipatedSeparationDate' => '2020-01-01',
              'title10ActivationDate' => '1999-03-04'
            },
            'unitName' => 'Seal Team Six',
            'unitPhone' => {
              'areaCode' => '123',
              'phoneNumber' => '1231231'
            }
          }
        }
      end
    end

    context 'when provided alternate names data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => []
            },
            'alternateNames' => [
              {
                'first' => 'Steve',
                'middle' => 'Steverson',
                'last' => 'Stevington'
              }
            ]
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [],
          'alternateNames' => [
            {
              'firstName' => 'Steve',
              'middleName' => 'Steverson',
              'lastName' => 'Stevington'
            }
          ]
        }
      end
    end
  end

  describe '#service_branch' do
    context 'when the service branch is on the branch map list' do
      it 'should transform it to the correct string' do
        expect(subject.send(:service_branch, 'Air Force Reserve')).to eq 'Air Force Reserves'
        expect(subject.send(:service_branch, 'Army Reserve')).to eq 'Army Reserves'
        expect(subject.send(:service_branch, 'Coast Guard Reserve')).to eq 'Coast Guard Reserves'
        expect(subject.send(:service_branch, 'Marine Corps Reserve')).to eq 'Marine Corps Reserves'
        expect(subject.send(:service_branch, 'Navy Reserve')).to eq 'Navy Reserves'
        expect(subject.send(:service_branch, 'NOAA')).to eq 'National Oceanic & Atmospheric Administration'
      end
    end

    context 'when the service branch is not on the branch map' do
      it 'should keep the service branch as is' do
        expect(subject.send(:service_branch, 'Navy')).to eq 'Navy'
      end
    end
  end

  describe '#translate_veteran' do
    context 'when provided email, phone, and va employee' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {},
            'emailAddress' => 'tester@adhocteam.us',
            'primaryPhone' => '5551231234',
            'isVAEmployee' => true
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'type' => 'INTERNATIONAL'
          },
          'emailAddress' => 'tester@adhocteam.us',
          'daytimePhone' => {
            'areaCode' => '555',
            'phoneNumber' => '1231234'
          },
          'currentlyVAEmployee' => true
        }
      end
    end

    context 'when given a Domestic address' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR',
              'addressLine1' => '1234 Couch Street',
              'zipCode' => '12345-6789'
            }
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'addressLine1' => '1234 Couch Street',
            'city' => 'Portland',
            'country' => 'USA',
            'state' => 'OR',
            'type' => 'DOMESTIC',
            'zipFirstFive' => '12345',
            'zipLastFour' => '6789'
          }
        }
      end
    end

    context 'when given a Military address' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {
              'country' => 'Germany',
              'city' => 'Hamburg',
              'state' => 'AA',
              'addressLine1' => '1234 Couch Strasse',
              'zipCode' => '12345-6789'
            }
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'addressLine1' => '1234 Couch Strasse',
            'militaryPostOfficeTypeCode' => 'Hamburg',
            'country' => 'Germany',
            'militaryStateCode' => 'AA',
            'type' => 'MILITARY',
            'zipFirstFive' => '12345',
            'zipLastFour' => '6789'
          }
        }
      end
    end

    context 'when given an International address' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {
              'country' => 'Germany',
              'city' => 'Hamburg',
              'addressLine1' => '1234 Couch Strasse'
            }
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'addressLine1' => '1234 Couch Strasse',
            'city' => 'Hamburg',
            'country' => 'Germany',
            'type' => 'INTERNATIONAL',
            'internationalPostalCode' => '732'
          }
        }
      end
    end

    context 'when given a change of address' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {},
            'forwardingAddress' => {
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR',
              'addressLine1' => '1234 Couch Street',
              'zipCode' => '12345-6789',
              'effectiveDate' => {
                'from' => '2018-02-01',
                'to' => '2018-02-30'
              }
            }
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'type' => 'INTERNATIONAL'
          },
          'changeOfAddress' => {
            'addressLine1' => '1234 Couch Street',
            'city' => 'Portland',
            'country' => 'USA',
            'state' => 'OR',
            'type' => 'DOMESTIC',
            'zipFirstFive' => '12345',
            'zipLastFour' => '6789',
            'beginningDate' => '2018-02-01',
            'endingDate' => '2018-02-30',
            'addressChangeType' => 'TEMPORARY'
          }
        }
      end
    end
  end

  describe '#translate_change_of_address' do
    context 'when given an effectiveDate `to` key' do
      let(:address) do
        {
          'effectiveDate' => {
            'from' => '2018-02-01',
            'to' => '2018-02-30'
          }
        }
      end

      it 'should set the address as TEMPORARY' do
        expect(subject.send(:translate_change_of_address, address)).to eq(
          'addressChangeType' => 'TEMPORARY',
          'beginningDate' => '2018-02-01',
          'endingDate' => '2018-02-30',
          'type' => 'INTERNATIONAL'
        )
      end
    end

    context 'when not given an effectiveDate `to` key' do
      let(:address) do
        {
          'effectiveDate' => {
            'from' => '2018-02-01'
          }
        }
      end

      it 'should set the address as PERMANENT' do
        expect(subject.send(:translate_change_of_address, address)).to eq(
          'addressChangeType' => 'PERMANENT',
          'beginningDate' => '2018-02-01',
          'type' => 'INTERNATIONAL'
        )
      end
    end
  end

  describe '#split_zip_code' do
    context 'when given a 5 number zip code' do
      it 'should return the correct split' do
        expect(subject.send(:split_zip_code, '12345')).to eq ['12345', '', nil]
      end
    end

    context 'when given a 9 number zip code' do
      it 'should return the correct split' do
        expect(subject.send(:split_zip_code, '123456789')).to eq ['12345', '', '6789']
      end
    end

    context 'when given a 9 number zip code with a hyphen' do
      it 'should return the correct split' do
        expect(subject.send(:split_zip_code, '12345-6789')).to eq ['12345', '-', '6789']
      end
    end
  end

  describe '#translate_homelessness' do
    context 'when `homelessOrAtRisk` is set to `no`' do
      let(:form_content) do
        {
          'form526' => {
            'homelessOrAtRisk' => 'no'
          }
        }
      end

      it 'returns nil' do
        expect(subject.send(:translate_homelessness)).to eq nil
      end
    end

    context 'when `homelessOrAtRisk` is set to `homeless`' do
      context 'and the user is fleeing their housing' do
        let(:form_content) do
          {
            'form526' => {
              'homelessOrAtRisk' => 'homeless',
              'needToLeaveHousing' => true,
              'otherHomelessHousing' => 'other living situation',
              'homelessnessContact' => {
                'name' => 'Steve Stevington',
                'phoneNumber' => '5551231234'
              }
            }
          }
        end

        it 'should translate the data correctly' do
          expect(subject.send(:translate_homelessness)).to eq(
            'pointOfContact' => {
              'pointOfContactName' => 'Steve Stevington',
              'primaryPhone' => {
                'areaCode' => '555',
                'phoneNumber' => '1231234'
              }
            },
            'currentlyHomeless' => {
              'homelessSituationType' => 'FLEEING_CURRENT_RESIDENCE',
              'otherLivingSituation' => 'other living situation'
            }
          )
        end
      end

      context 'and the user is not fleeing their housing' do
        let(:form_content) do
          {
            'form526' => {
              'homelessOrAtRisk' => 'homeless',
              'homelessHousingSituation' => 'shelter',
              'otherHomelessHousing' => 'other living situation',
              'homelessnessContact' => {
                'name' => 'Steve Stevington',
                'phoneNumber' => '5551231234'
              }
            }
          }
        end

        it 'should translate the data correctly' do
          expect(subject.send(:translate_homelessness)).to eq(
            'pointOfContact' => {
              'pointOfContactName' => 'Steve Stevington',
              'primaryPhone' => {
                'areaCode' => '555',
                'phoneNumber' => '1231234'
              }
            },
            'currentlyHomeless' => {
              'homelessSituationType' => 'LIVING_IN_A_HOMELESS_SHELTER',
              'otherLivingSituation' => 'other living situation'
            }
          )
        end
      end
    end

    context 'when `homelessOrAtRisk` is set to `atRisk`' do
      let(:form_content) do
        {
          'form526' => {
            'homelessOrAtRisk' => 'atRisk',
            'atRiskHousingSituation' => 'losingHousing',
            'otherAtRiskHousing' => 'other living situation',
            'homelessnessContact' => {
              'name' => 'Steve Stevington',
              'phoneNumber' => '5551231234'
            }
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_homelessness)).to eq(
          'pointOfContact' => {
            'pointOfContactName' => 'Steve Stevington',
            'primaryPhone' => {
              'areaCode' => '555',
              'phoneNumber' => '1231234'
            }
          },
          'homelessnessRisk' => {
            'homelessnessRiskSituationType' => 'HOUSING_WILL_BE_LOST_IN_30_DAYS',
            'otherLivingSituation' => 'other living situation'
          }
        )
      end
    end
  end

  describe '#translate_treatments' do
    context 'when no treatment centers are provided' do
      it 'should return an empty hash' do
        expect(subject.send(:translate_treatments)).to eq({})
      end
    end

    context 'when given a treatment center' do
      let(:form_content) do
        {
          'form526' => {
            'vaTreatmentFacilities' => [
              {
                'treatmentDateRange' => {
                  'from' => '2018-01-01',
                  'to' => '2018-02-01'
                },
                'treatmentCenterName' => 'Super Hospital',
                'treatmentCenterAddress' => {
                  'country' => 'USA',
                  'city' => 'Portland',
                  'state' => 'OR'
                },
                'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3]
              }
            ]
          }
        }
      end

      it 'should translate the data correctly' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
            'startDate' => '2018-01-01',
            'endDate' => '2018-02-01',
            'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3],
            'center' => {
              'name' => 'Super Hospital',
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR'
            }
          }
        ]
      end
    end
  end

  describe '#translate_disabilities' do
    context 'when there are no new disabilities' do
      let(:form_content) do
        {
          'form526' => {
            'disabilities' => [
              {
                'diagnosticCode' => 9999,
                'disabilityActionType' => 'NEW',
                'name' => 'PTSD (post traumatic stress disorder)',
                'ratedDisabilityId' => '1100583'
              }
            ]
          }
        }
      end

      it 'should translate only the preexisting disabilities' do
        expect(subject.send(:translate_disabilities)).to eq 'disabilities' => [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD (post traumatic stress disorder)',
            'ratedDisabilityId' => '1100583'
          }
        ]
      end
    end
  end

  describe '#translate_new_disabilities' do
    context 'when there is a NEW disability' do
      let(:form_content) do
        {
          'form526' => {
            'newDisabilities' => [
              {
                'cause' => 'NEW',
                'condition' => 'new condition',
                'primaryDescription' => 'new condition description'
              }
            ]
          }
        }
      end

      it 'should translate only the NEW disabilities' do
        expect(subject.send(:translate_new_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'new condition',
            'serviceRelevance' => "Caused by an in-service event, injury, or exposure\nnew condition description"
          }
        ]
      end
    end

    context 'when there is a WORSENED disability' do
      let(:form_content) do
        {
          'form526' => {
            'newDisabilities' => [
              {
                'cause' => 'WORSENED',
                'condition' => 'worsened condition',
                'worsenedDescription' => 'worsened condition description',
                'worsenedEffects' => 'worsened effects'
              }
            ]
          }
        }
      end

      it 'should translate only the WORSENED disabilities' do
        expect(subject.send(:translate_new_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'worsened condition',
            'serviceRelevance' =>
              "Worsened because of military service\nworsened condition description: worsened effects"
          }
        ]
      end
    end

    context 'when there is a VA disability' do
      let(:form_content) do
        {
          'form526' => {
            'newDisabilities' => [
              {
                'cause' => 'VA',
                'condition' => 'va condition',
                'VAMistreatmentDescription' => 'va condition description',
                'VAMistreatmentLocation' => 'va location',
                'VAMistreatmentDate' => 'the third of october'
              }
            ]
          }
        }
      end

      it 'should translate only the VA disabilities' do
        expect(subject.send(:translate_new_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'va condition',
            'serviceRelevance' =>
              "Caused by VA care\nEvent: va condition description\n"\
              "Location: va location\nTimeFrame: the third of october"
          }
        ]
      end
    end

    context 'when there are SECONDARY disabilities' do
      let(:form_content) do
        {
          'form526' => {
            'newDisabilities' => [
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition',
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD disability'
              },
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition2',
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD disability2'
              },
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition3',
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD disability2'
              }
            ]
          }
        }
      end

      let(:disability) do
        [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability',
            'ratedDisabilityId' => '1100583'
          },
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability2',
            'ratedDisabilityId' => '1100583'
          }
        ]
      end

      it 'should translate SECONDARY disability to a current disability' do
        expect(subject.send(:translate_new_disabilities, disability)).to eq [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability',
            'ratedDisabilityId' => '1100583',
            'secondaryDisabilities' => [
              {
                'name' => 'secondary condition',
                'disabilityActionType' => 'SECONDARY',
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              }
            ]
          },
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability2',
            'ratedDisabilityId' => '1100583',
            'secondaryDisabilities' => [
              {
                'name' => 'secondary condition2',
                'disabilityActionType' => 'SECONDARY',
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              },
              {
                'name' => 'secondary condition3',
                'disabilityActionType' => 'SECONDARY',
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              }
            ]
          }
        ]
      end
    end
  end

  describe '#application_expiration_date' do
    let(:past) { Time.zone.now - 1.month }
    let(:now) { Time.zone.now }
    let(:future) { Time.zone.now + 1.month }

    context 'when the RAD date is more recent than the application creation date' do
      before do
        allow(subject).to receive(:application_create_date).and_return(past)
        allow(subject).to receive(:rad_date).and_return(now)
      end

      it 'should return the RAD date + 366 days' do
        return_date = (now + 366.days).iso8601
        expect(subject.send(:application_expiration_date)).to eq return_date
      end
    end

    context 'when the RAD date does not exist' do
      before do
        allow(subject).to receive(:rad_date).and_return(nil)
      end

      let!(:itf) do
        EVSS::IntentToFile::IntentToFile.new(
          'status' => 'active',
          'type' => 'compensation',
          'creation_date' => nil,
          'expiration_date' => nil
        )
      end

      context 'when the ITF creation date is nil' do
        before do
          allow(subject).to receive(:application_create_date).and_return(now)
          allow(subject).to receive(:itf).and_return(itf)
        end

        it 'should return the application creation date + 365 days' do
          return_date = (now + 365.days).iso8601
          expect(subject.send(:application_expiration_date)).to eq return_date
        end
      end

      context 'when the ITF expiration date is nil' do
        before do
          allow(subject).to receive(:application_create_date).and_return(now)
          itf.creation_date = past
          allow(subject).to receive(:itf).and_return(itf)
        end

        it 'should return the application creation date + 365 days' do
          return_date = (now + 365.days).iso8601
          expect(subject.send(:application_expiration_date)).to eq return_date
        end
      end

      context 'when the ITF creation date is more recent than the application creation date' do
        before do
          allow(subject).to receive(:application_create_date).and_return(past)
          itf.creation_date = now
          itf.expiration_date = future
          allow(subject).to receive(:itf).and_return(itf)
        end

        it 'should return the application creation date + 365 days' do
          return_date = (past + 365.days).iso8601
          expect(subject.send(:application_expiration_date)).to eq return_date
        end
      end

      context 'when the ITF creation date isolder than the application creation date' do
        before do
          allow(subject).to receive(:application_create_date).and_return(now)
          itf.creation_date = past
          itf.expiration_date = future
          allow(subject).to receive(:itf).and_return(itf)
        end

        it 'should return the application creation date + 365 days' do
          expect(subject.send(:application_expiration_date)).to eq itf.expiration_date.iso8601
        end
      end
    end
  end
end
