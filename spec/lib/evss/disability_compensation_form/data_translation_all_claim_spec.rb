# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/data_translation_all_claim'

describe EVSS::DisabilityCompensationForm::DataTranslationAllClaim do
  subject { described_class.new(user, form_content, false) }

  let(:form_content) { { 'form526' => {} } }

  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
    frozen_time = Time.zone.parse '2020-11-05 13:19:50 -0500'
    Timecop.freeze(frozen_time)
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT)
  end

  after { Timecop.return }

  describe '#redacted' do
    context 'when the banking numbers include a *' do
      it 'returns true' do
        expect(subject.send('redacted', '**234', '1212')).to eq(
          true
        )
      end
    end

    context 'when the banking numbers dont include a *' do
      it 'returns false' do
        expect(subject.send('redacted', '234', '1212')).to eq(
          false
        )
      end
    end

    context 'when the banking numbers are nil' do
      it 'returns falsey' do
        expect(subject.send('redacted', nil, nil)).to be_falsey
      end
    end
  end

  describe '#translate' do
    context 'all claims' do
      before do
        create(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: user.uuid)
      end

      let(:form_content) do
        JSON.parse(File.read('spec/support/disability_compensation_form/all_claims_fe_submission.json'))
      end
      let(:evss_json) { File.read 'spec/support/disability_compensation_form/all_claims_evss_submission.json' }

      it 'returns correctly formatted json to send to EVSS' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          VCR.use_cassette('emis/get_military_service_episodes/valid', allow_playback_repeats: true) do
            expect(subject.translate).to eq JSON.parse(evss_json)
          end
        end
      end
    end

    context 'kitchen sink BDD' do
      before do
        create(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: user.uuid)
        Timecop.freeze(Date.new(2020, 8, 1))
      end

      after { Timecop.return }

      let(:form_content) do
        JSON.parse(File.read('spec/support/disability_compensation_form/bdd_large_fe_submission.json'))
      end

      let(:evss_json) { File.read 'spec/support/disability_compensation_form/bdd_evss_submission.json' }

      it 'returns correctly formatted json to send to EVSS' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          VCR.use_cassette('emis/get_military_service_episodes/valid', allow_playback_repeats: true) do
            expect(subject.translate).to eq JSON.parse(evss_json)
          end
        end
      end
    end
  end

  describe '#overflow_text' do
    context 'when the form has a 4142 and the vet is terminally ill' do
      subject { described_class.new(user, form_content, true) }

      let(:form_content) do
        {
          'form526' => {
            'isTerminallyIll' => true
          }
        }
      end

      it 'adds the correct overflow text' do
        expect(subject.send(:overflow_text)).to eq "Corporate Flash Details\n" \
                                                   "This applicant has indicated that they're terminally ill.\n" \
                                                   'VA Form 21-4142/4142a has been completed by the applicant and ' \
                                                   'sent to the PMR contractor for processing in accordance with ' \
                                                   'M21-1 III.iii.1.D.2.'
      end
    end

    context 'when the form only has a 4142' do
      subject { described_class.new(user, form_content, true) }

      it 'adds the correct overflow text' do
        expect(subject.send(:overflow_text)).to eq 'VA Form 21-4142/4142a has been completed ' \
                                                   'by the applicant and sent to the PMR contractor ' \
                                                   'for processing in accordance with M21-1 III.iii.1.D.2.'
      end
    end

    context 'when the vet is terminally ill only' do
      let(:form_content) do
        {
          'form526' => {
            'isTerminallyIll' => true
          }
        }
      end

      it 'adds the correct overflow text' do
        expect(subject.send(:overflow_text)).to eq "Corporate Flash Details\n" \
                                                   "This applicant has indicated that they're terminally ill.\n"
      end
    end

    context 'when the vet has no overflow text' do
      let(:form_content) do
        {
          'form526' => {
            'isTerminallyIll' => false
          }
        }
      end

      it 'adds the correct overflow text' do
        expect(subject.send(:overflow_text)).to eq nil
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

      it 'translates the data correctly' do
        expect(subject.send(:translate_banking_info)).to eq 'directDeposit' => {
          'accountType' => 'CHECKING',
          'accountNumber' => '1234567890',
          'routingNumber' => '0987654321',
          'bankName' => 'test'
        }
      end
    end

    context 'when the banking info is redacted' do
      let(:form_content) do
        {
          'form526' => {
            'bankName' => 'test',
            'bankAccountType' => 'checking',
            'bankAccountNumber' => '**34567890',
            'bankRoutingNumber' => '0987654321'
          }
        }
      end

      it 'gathers the banking info from the PPIU service' do
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

    context 'when not provided banking info' do
      context 'and the PPIU service has the account info' do
        it 'gathers the banking info from the PPIU service' do
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

        it 'does not set payment information' do
          expect(EVSS::PPIU::Service).to receive(:new).once.and_return(response)
          expect(subject.send(:translate_banking_info)).to eq({})
        end
      end
    end
  end

  describe '#translate_service_pay' do
    context 'when no relevant data is provided' do
      it 'returns an empty hash' do
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

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_pay)).to eq 'servicePay' => {
          'waiveVABenefitsToRetainTrainingPay' => true,
          'waiveVABenefitsToRetainRetiredPay' => true
        }
      end
    end

    context 'when provided military retired data' do
      let(:form_content) { { 'form526' => { 'militaryRetiredPayBranch' => 'Air Force' } } }

      it 'translates the data correctly' do
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
            'hasSeparationPay' => true,
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-XX-XX'
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_pay)).to eq 'servicePay' => {
          'separationPay' => {
            'received' => true,
            'payment' => {
              'serviceBranch' => 'Air Force'
            },
            'receivedDate' => {
              'year' => '2018'
            }
          }
        }
      end
    end
  end

  describe '#separation_pay' do
    context 'when given all separation pay data' do
      let(:form_content) do
        {
          'form526' => {
            'hasSeparationPay' => true,
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-XX-XX'
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:separation_pay)).to eq(
          'received' => true,
          'payment' => {
            'serviceBranch' => 'Air Force'
          },
          'receivedDate' => {
            'year' => '2018'
          }
        )
      end
    end

    context 'when `hasSeparationPay` is false' do
      let(:form_content) do
        {
          'form526' => {
            'hasSeparationPay' => false,
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-XX-XX'
          }
        }
      end

      it 'does not translate separation pay' do
        expect(subject.send(:separation_pay)).to eq nil
      end
    end

    context 'when `hasSeparationPay` does not exist' do
      let(:form_content) do
        {
          'form526' => {
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-XX-XX'
          }
        }
      end

      it 'does not translate separation pay' do
        expect(subject.send(:separation_pay)).to eq nil
      end
    end

    context 'when given no optional separation pay data' do
      let(:form_content) do
        {
          'form526' => {
            'hasSeparationPay' => true
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:separation_pay)).to eq('received' => true)
      end
    end
  end

  describe '#translate_service_info' do
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

      it 'translates the data correctly' do
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

    context 'when provided service separation location' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '2021-04-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ],
              'separationLocation' => {
                'separationLocationCode' => '98283',
                'separationLocationName' => 'AF Academy'
              }
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '2021-04-02'
            }
          ],
          'separationLocationCode' => '98283',
          'separationLocationName' => 'AF Academy'
        }
      end
    end

    context 'when provided confinements data' do
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

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '1990-01-02'
            }
          ],
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
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '1990-01-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ],
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
            'waiveTrainingPay' => true,
            'hasTrainingPay' => true
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '1990-01-02'
            }
          ],
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
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '1990-01-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            },
            'alternateNames' => [
              {
                'first' => 'Steve',
                'middle' => 'Steverson',
                'last' => 'Stevington'
              },
              {
                'first' => 'Steve',
                'middle' => 'Steverson',
                'last' => 'Stevington'
              }
            ]
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '1990-01-02'
            }
          ],
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
      it 'transforms it to the correct string' do
        expect(subject.send(:service_branch, 'Air Force Reserve')).to eq 'Air Force Reserves'
        expect(subject.send(:service_branch, 'Army Reserve')).to eq 'Army Reserves'
        expect(subject.send(:service_branch, 'Coast Guard Reserve')).to eq 'Coast Guard Reserves'
        expect(subject.send(:service_branch, 'Marine Corps Reserve')).to eq 'Marine Corps Reserves'
        expect(subject.send(:service_branch, 'Navy Reserve')).to eq 'Navy Reserves'
        expect(subject.send(:service_branch, 'NOAA')).to eq 'National Oceanic & Atmospheric Administration'
      end
    end

    context 'when the service branch is not on the branch map' do
      it 'keeps the service branch as is' do
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
            'phoneAndEmail' => {
              'emailAddress' => 'tester@adhocteam.us',
              'primaryPhone' => '5551231234'
            },
            'isVaEmployee' => true
          }
        }
      end

      it 'translates the data correctly' do
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

      it 'translates the data correctly' do
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
              'city' => ' apo ',
              'state' => 'AA',
              'addressLine1' => '1234 Couch Strasse',
              'zipCode' => '12345-6789'
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'addressLine1' => '1234 Couch Strasse',
            'militaryPostOfficeTypeCode' => 'APO',
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

      it 'translates the data correctly' do
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

      it 'translates the data correctly' do
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

      it 'sets the address as TEMPORARY' do
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

      it 'sets the address as PERMANENT' do
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
      it 'returns the correct split' do
        expect(subject.send(:split_zip_code, '12345')).to eq ['12345', '', nil]
      end
    end

    context 'when given a 9 number zip code' do
      it 'returns the correct split' do
        expect(subject.send(:split_zip_code, '123456789')).to eq ['12345', '', '6789']
      end
    end

    context 'when given a 9 number zip code with a hyphen' do
      it 'returns the correct split' do
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

        it 'translates the data correctly' do
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

        it 'translates the data correctly' do
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

      it 'translates the data correctly' do
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
      it 'returns an empty hash' do
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
                  'to' => '2018-02-XX'
                },
                'treatmentCenterName' => 'Super  _,!?Hospital    \'&\' "More" (#2.0)',
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

      it 'translates the data correctly, including regex evaluation of center name' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
            'startDate' => {
              'year' => '2018',
              'month' => '01',
              'day' => '01'
            },
            'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3],
            'center' => {
              'name' => 'Super Hospital \'&\' "More" (#2.0)',
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR'
            }
          }
        ]
      end
    end

    context 'when given a treatment center with no `to` date' do
      let(:form_content) do
        {
          'form526' => {
            'vaTreatmentFacilities' => [
              {
                'treatmentDateRange' => {
                  'from' => '2018-01-01',
                  'to' => ''
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

      it 'translates the data correctly' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
            'startDate' => {
              'year' => '2018',
              'month' => '01',
              'day' => '01'
            },
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

    context 'when given a treatment center an incomplete "from" date' do
      let(:form_content) do
        {
          'form526' => {
            'vaTreatmentFacilities' => [
              {
                'treatmentDateRange' => {
                  'from' => 'XXXX-07-XX',
                  'to' => ''
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

      it 'translates the data correctly' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
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

    context 'when given a treatment center with no date' do
      let(:form_content) do
        {
          'form526' => {
            'vaTreatmentFacilities' => [
              {
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

      it 'translates the data correctly' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
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
            'ratedDisabilities' => [
              {
                'diagnosticCode' => 9999,
                'disabilityActionType' => 'INCREASE',
                'name' => 'PTSD (post traumatic stress disorder)',
                'ratedDisabilityId' => '1100583'
              }
            ]
          }
        }
      end

      it 'translates only the preexisting disabilities' do
        expect(subject.send(:translate_disabilities)).to eq 'disabilities' => [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'INCREASE',
            'name' => 'PTSD (post traumatic stress disorder)',
            'ratedDisabilityId' => '1100583'
          }
        ]
      end
    end

    context 'when there is an extraneous `NONE` action type disability' do
      let(:form_content) do
        {
          'form526' => {
            'ratedDisabilities' => [
              {
                'diagnosticCode' => 9999,
                'disabilityActionType' => 'INCREASE',
                'name' => 'PTSD (post traumatic stress disorder)',
                'ratedDisabilityId' => '1100583'
              },
              {
                'diagnosticCode' => 9998,
                'disabilityActionType' => 'NONE',
                'name' => 'Arthritis',
                'ratedDisabilityId' => '1100582'
              }
            ]
          }
        }
      end

      it 'does not translate the disability with NONE action type' do
        expect(subject.send(:translate_disabilities)).to eq 'disabilities' => [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'INCREASE',
            'name' => 'PTSD (post traumatic stress disorder)',
            'ratedDisabilityId' => '1100583'
          }
        ]
      end
    end

    context 'when there is an  `NONE` action type disability but it has a new secondary disability' do
      let(:form_content) do
        {
          'form526' => {
            'ratedDisabilities' => [
              {
                'diagnosticCode' => 9999,
                'disabilityActionType' => 'NONE',
                'name' => 'PTSD (post traumatic stress disorder)',
                'ratedDisabilityId' => '1100583'
              }
            ],
            'newSecondaryDisabilities' => [
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition',
                'specialIssues' => ['POW'],
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD (post traumatic stress disorder)'
              }
            ]
          }
        }
      end

      it 'translates the NONE action type disability and its secondary disability' do
        expect(subject.send(:translate_disabilities)).to eq 'disabilities' => [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NONE',
            'name' => 'PTSD (post traumatic stress disorder)',
            'ratedDisabilityId' => '1100583',
            'secondaryDisabilities' => [
              {
                'name' => 'secondary condition',
                'disabilityActionType' => 'SECONDARY',
                'specialIssues' => ['POW'],
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              }
            ]
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
            'newPrimaryDisabilities' => [
              {
                'cause' => 'NEW',
                'condition' => 'new condition',
                'classificationCode' => 'Test Code',
                'specialIssues' => ['POW'],
                'primaryDescription' => 'new condition description'
              }
            ]
          }
        }
      end

      it 'translates only the NEW disabilities' do
        expect(subject.send(:translate_new_primary_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'new condition',
            'classificationCode' => 'Test Code',
            'specialIssues' => ['POW'],
            'serviceRelevance' => "Caused by an in-service event, injury, or exposure\nnew condition description"
          }
        ]
      end
    end

    context 'when there is a WORSENED disability' do
      let(:form_content) do
        {
          'form526' => {
            'newPrimaryDisabilities' => [
              {
                'cause' => 'WORSENED',
                'condition' => 'worsened condition',
                'classificationCode' => 'Test Code',
                'specialIssues' => ['POW'],
                'worsenedDescription' => 'worsened condition description',
                'worsenedEffects' => 'worsened effects'
              }
            ]
          }
        }
      end

      it 'translates only the WORSENED disabilities' do
        expect(subject.send(:translate_new_primary_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'worsened condition',
            'classificationCode' => 'Test Code',
            'specialIssues' => ['POW'],
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
            'newPrimaryDisabilities' => [
              {
                'cause' => 'VA',
                'condition' => 'va condition',
                'classificationCode' => 'Test Code',
                'specialIssues' => ['POW'],
                'vaMistreatmentDescription' => 'va condition description',
                'vaMistreatmentLocation' => 'va location',
                'vaMistreatmentDate' => 'the third of october'
              }
            ]
          }
        }
      end

      it 'translates only the VA disabilities' do
        expect(subject.send(:translate_new_primary_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'va condition',
            'classificationCode' => 'Test Code',
            'specialIssues' => ['POW'],
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
            'newSecondaryDisabilities' => [
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition',
                'classificationCode' => 'Test Code',
                'specialIssues' => ['POW'],
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD disability'
              },
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition2',
                'specialIssues' => ['POW'],
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD disability2'
              },
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition3',
                'specialIssues' => ['POW'],
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'ptsd disability2' # check that the match is case insensitive
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
            'classificationCode' => 'Test Code',
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

      it 'translates SECONDARY disability to a current disability' do
        expect(subject.send(:translate_new_secondary_disabilities, disability)).to eq [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability',
            'classificationCode' => 'Test Code',
            'ratedDisabilityId' => '1100583',
            'secondaryDisabilities' => [
              {
                'name' => 'secondary condition',
                'classificationCode' => 'Test Code',
                'disabilityActionType' => 'SECONDARY',
                'specialIssues' => ['POW'],
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
                'specialIssues' => ['POW'],
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              },
              {
                'name' => 'secondary condition3',
                'disabilityActionType' => 'SECONDARY',
                'specialIssues' => ['POW'],
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              }
            ]
          }
        ]
      end
    end

    context 'when there is a new disability without a classificationCode' do
      let(:form_content) do
        {
          'form526' => {
            'newPrimaryDisabilities' => [
              {
                'cause' => 'NEW',
                'condition' => '  brand [new] disability { to  be } rated',
                'primaryDescription' => 'new condition description'
              }
            ]
          }
        }
      end

      it 'translates only the NEW disabilities' do
        expect(subject.send(:translate_new_primary_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'brand new disability to be rated',
            'serviceRelevance' => "Caused by an in-service event, injury, or exposure\nnew condition description"
          }
        ]
      end
    end

    describe '#scrub_disability_condition' do
      context 'when given a condition name' do
        let(:condition1) { 'this is only a test' }
        let(:condition2) { '  this    is only     a      test ' }
        let(:condition3) { '[ \'this\'  is ] (only) a ’test’' }
        let(:condition4) { 'this-is,only.a-test' }
        let(:condition5) { 'this ¢is onÈly a töest' }

        it 'scrubs out any illegal characters' do
          expect(subject.send(:scrub_disability_condition, condition1)).to eq 'this is only a test'
          expect(subject.send(:scrub_disability_condition, condition2)).to eq 'this is only a test'
          expect(subject.send(:scrub_disability_condition, condition3)).to eq '\'this\' is (only) a test'
          expect(subject.send(:scrub_disability_condition, condition4)).to eq 'this-is,only.a-test'
          expect(subject.send(:scrub_disability_condition, condition5)).to eq 'this is only a test'
        end
      end
    end

    describe '#approximate_date' do
      context 'when there is a full date' do
        let(:date) { '2099-12-01' }

        it 'returns the year, month, and day' do
          expect(subject.send(:approximate_date, date)).to include(
            'year' => '2099',
            'month' => '12',
            'day' => '01'
          )
        end
      end

      context 'when there is a partial date (year and month)' do
        let(:date) { '2099-12-XX' }

        it 'returns the year and month' do
          expect(subject.send(:approximate_date, date)).to include(
            'year' => '2099',
            'month' => '12'
          )
        end
      end

      context 'when there is a partial date (year only)' do
        let(:date) { '2099-XX-XX' }

        it 'returns the year' do
          expect(subject.send(:approximate_date, date)).to include(
            'year' => '2099'
          )
        end
      end

      context 'when there is no date' do
        let(:date) { '' }

        it 'returns the year' do
          expect(subject.send(:approximate_date, date)).to eq nil
        end
      end
    end
  end

  describe '#application_expiration_date' do
    it 'returns the application creation date + 365 days' do
      expect(subject.send(:application_expiration_date)).to eq '2021-11-05T18:19:50Z'
    end
  end

  describe '#translate_bdd' do
    let(:today) { Time.now.in_time_zone('Central Time (US & Canada)').to_date }

    context 'when rad date is > 180 away' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => (today + 181).to_s
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            }
          }
        }
      end

      it 'throws 422 error' do
        expect { subject.send(:bdd_qualified?) }.to raise_error(
          Common::Exceptions::UnprocessableEntity
        ) { |e|
          expect(e.errors[0].detail).to match(/more than 180 days/)
        }
      end
    end

    context 'when rad date is 90 days away' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => (today + 90).to_s
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            }
          }
        }
      end

      it 'bdd_qualified is true' do
        expect(subject.send(:bdd_qualified?)).to eq true
      end

      context 'when only gurard/reserves' do
        let(:form_content) do
          {
            'form526' => {
              'serviceInformation' => {
                'servicePeriods' => [
                  {
                    'dateRange' => {
                      'from' => '1980-02-05',
                      'to' => (today + 100).to_s
                    },
                    'serviceBranch' => 'Air National Guard'
                  }
                ]
              }
            }
          }
        end

        it 'bdd_qualified is true' do
          expect(subject.send(:bdd_qualified?)).to eq false
        end
      end

      context 'activated in guard' do
        let(:form_content) do
          {
            'form526' => {
              'serviceInformation' => {
                'reservesNationalGuardService' => {
                  'title10Activation' => {
                    'anticipatedSeparationDate' => (today + 100).to_s,
                    'title10ActivationDate' => '2015-01-01'
                  }
                },
                'servicePeriods' => [
                  {
                    'dateRange' => {
                      'from' => '1980-02-05',
                      'to' => '2120-01-01'
                    },
                    'serviceBranch' => 'Air National Guard'
                  }
                ]
              }
            }
          }
        end

        it 'bdd_qualified is true' do
          expect(subject.send(:bdd_qualified?)).to eq true
        end
      end
    end

    context 'when rad date is < 90 days away' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => (today + 89).to_s
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            }
          }
        }
      end

      it 'bdd_qualified is false' do
        expect(subject.send(:bdd_qualified?)).to eq false
      end
    end
  end
end
