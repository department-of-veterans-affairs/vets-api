# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/disability_compensation_pdf_mapper'

describe ClaimsApi::V1::DisabilityCompensationPdfMapper do
  let(:pdf_data) do
    {
      data: {
        attributes:
          {}
      }
    }
  end
  let(:auto_claim) do
    JSON.parse(
      Rails.root.join(
        'modules',
        'claims_api',
        'spec',
        'fixtures',
        'form_526_json_api.json'
      ).read
    )
  end
  let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
  let(:user) { create(:user, :loa3) }
  let(:created_at) { Timecop.freeze(Time.zone.now) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:middle_initial) { 'L' }
  let(:mapper) do
    ClaimsApi::V1::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, auth_headers, middle_initial,
                                                       created_at)
  end

  context '526 section 0, claim attributes', run_at: '2025-09-03 11:57:45.709631 -0500' do
    it 'set claimProcessType as STANDARD_CLAIM_PROCESS when standardClaim is true' do
      form_attributes['standardClaim'] = true
      mapper.map_claim

      claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

      expect(claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
    end

    it 'set claimProcessType as FDC_PROGRAM when standardClaim is false' do
      mapper.map_claim

      claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

      expect(claim_process_type).to eq('FDC_PROGRAM')
    end

    it 'set claimProcessType as BDD_PROGRAM when activeDutyEndDate is between 90 - 180 days in the future' do
      form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = '2025-12-03' # 91 days
      mapper.map_claim

      claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

      expect(claim_process_type).to eq('BDD_PROGRAM')
    end

    it 'set claimProcessType as BDD_PROGRAM when activeDutyEndDate is exactly 90 days in the future' do
      form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = '2025-12-02' # 90 days
      mapper.map_claim

      claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

      expect(claim_process_type).to eq('BDD_PROGRAM')
    end

    it 'set claimProcessType as BDD_PROGRAM when activeDutyEndDate is exactly 180 days in the future' do
      form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = '2026-03-02' # 180 days
      mapper.map_claim

      claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

      expect(claim_process_type).to eq('BDD_PROGRAM')
    end
  end

  context '526 section 1, veteran identification' do
    let(:birls_file_number) { auth_headers['va_eauth_birlsfilenumber'] }
    let(:first_name) { auth_headers['va_eauth_firstName'] }
    let(:last_name) { auth_headers['va_eauth_lastName'] }

    it 'maps the mailing address' do
      mapper.map_claim

      address_base = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress]

      expect(address_base[:numberAndStreet]).to eq('1234 Couch Street Apt. 22')
      expect(address_base[:city]).to eq('Portland')
      expect(address_base[:state]).to eq('OR')
      expect(address_base[:country]).to eq('USA')
      expect(address_base[:zip]).to eq('12345-6789')
    end

    it 'maps international mailing address' do
      form_attributes['veteran']['currentMailingAddress']['internationalPostalCode'] = '98761'
      form_attributes['veteran']['currentMailingAddress']['country'] = 'Australia'
      mapper.map_claim

      address_base = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress]

      expect(address_base[:country]).to eq('Australia')
      expect(address_base[:zip]).to eq('98761')
    end

    it 'maps the veteran personal information' do
      mapper.map_claim

      employee_status = pdf_data[:data][:attributes][:identificationInformation][:currentVaEmployee]
      veteran_ssn = pdf_data[:data][:attributes][:identificationInformation][:ssn]
      va_file_number = pdf_data[:data][:attributes][:identificationInformation][:vaFileNumber]
      veteran_name = pdf_data[:data][:attributes][:identificationInformation][:name]
      birth_date = pdf_data[:data][:attributes][:identificationInformation][:dateOfBirth]

      expect(employee_status).to be(false)
      expect(veteran_ssn).to eq('796-11-1863')
      expect(va_file_number).to eq(birls_file_number)
      expect(veteran_name).to eq({ lastName: 'lincoln', middleInitial: 'L', firstName: 'abraham' })
      expect(birth_date).to eq({ month: '02', day: '12', year: '1809' })
    end
  end

  context 'section 2, change of address' do
    let(:change_of_address) do
      {
        'beginningDate' => '2018-06-04',
        'endingDate' => '2018-06-08',
        'addressChangeType' => 'TEMPORARY',
        'addressLine1' => '1234 Couch Street',
        'addressLine2' => 'Apt. 22',
        'city' => 'Portland',
        'country' => 'USA',
        'state' => 'OR',
        'zipFirstFive' => '12345',
        'zipLastFour' => '9876'
      }
    end

    before do
      form_attributes['veteran']['changeOfAddress'] = change_of_address
    end

    it 'maps the changeOfAddress beginning and end dates' do
      mapper.map_claim
      change_of_address_dates_base = pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates]

      expect(change_of_address_dates_base[:end]).to eq({ year: '2018', month: '06', day: '08' })
      expect(change_of_address_dates_base[:start]).to eq({ year: '2018', month: '06', day: '04' })
    end

    it 'maps the new address' do
      mapper.map_claim
      change_of_address_address_base = pdf_data[:data][:attributes][:changeOfAddress][:newAddress]

      expect(change_of_address_address_base[:numberAndStreet]).to eq('1234 Couch Street Apt. 22')
      expect(change_of_address_address_base[:city]).to eq('Portland')
      expect(change_of_address_address_base[:state]).to eq('OR')
      expect(change_of_address_address_base[:country]).to eq('US')
      expect(change_of_address_address_base[:zip]).to eq('12345-9876')
    end

    it 'maps an international postal code' do
      int_zip = '96753'
      form_attributes['veteran']['changeOfAddress']['country'] = 'Australia'
      form_attributes['veteran']['changeOfAddress']['zipFirstFive'] = nil
      form_attributes['veteran']['changeOfAddress']['zipLastFour'] = nil
      form_attributes['veteran']['changeOfAddress']['internationalPostalCode'] = int_zip
      mapper.map_claim
      change_of_address_address_base = pdf_data[:data][:attributes][:changeOfAddress][:newAddress]

      expect(change_of_address_address_base[:zip]).to eq(int_zip)
    end

    it 'maps the type of address change' do
      mapper.map_claim
      change_of_address_address_base = pdf_data[:data][:attributes][:changeOfAddress]

      expect(change_of_address_address_base[:typeOfAddressChange]).to eq('TEMPORARY')
    end
  end

  describe 'section 3, homeless information' do
    context 'when homeless information is included in the submission' do
      context 'pointOfContact attributes' do
        it 'maps the attributes if included' do
          mapper.map_claim

          homeless_base = pdf_data[:data][:attributes][:homelessInformation]

          expect(homeless_base[:pointOfContact]).to eq('Firstname Lastname')
          expect(homeless_base[:pointOfContactNumber][:telephone]).to eq('123-555-1234')
        end

        it 'does not map anything if not included' do
          form_attributes['veteran']['homelessness']['pointOfContact'] = nil
          mapper.map_claim

          homeless_base = pdf_data[:data][:attributes][:homelessInformation]

          expect(homeless_base).not_to have_key(:pointOfContact)
          expect(homeless_base).not_to have_key(:pointOfContactNumber)
        end
      end

      context 'currentlyHomeless attributes' do
        it 'maps the attributes if included' do
          mapper.map_claim

          currently_homeless_base = pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless]

          expect(currently_homeless_base[:homelessSituationOptions]).to eq('FLEEING_CURRENT_RESIDENCE')
          expect(currently_homeless_base[:otherDescription]).to eq('none')
        end

        it 'does not map anything if not included' do
          form_attributes['veteran']['homelessness']['currentlyHomeless'] = nil
          mapper.map_claim

          homeless_base = pdf_data[:data][:attributes][:homelessInformation]

          expect(homeless_base).not_to have_key(:currentlyHomeless)
        end

        context 'mapping the enums' do
          before do
            form_attributes['veteran']['homelessness']['currentlyHomeless'] = {}
          end

          it "maps 'fleeing' to 'FLEEING_CURRENT_RESIDENCE'" do
            form_attributes['veteran']['homelessness']['currentlyHomeless']['homelessSituationType'] =
              'fleeing'
            mapper.map_claim

            homeless_base = pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless]

            expect(homeless_base[:homelessSituationOptions]).to eq('FLEEING_CURRENT_RESIDENCE')
          end

          it "maps 'shelter' to 'LIVING_IN_A_HOMELESS_SHELTER'" do
            form_attributes['veteran']['homelessness']['currentlyHomeless']['homelessSituationType'] =
              'shelter'
            mapper.map_claim

            homeless_base = pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless]

            expect(homeless_base[:homelessSituationOptions]).to eq('LIVING_IN_A_HOMELESS_SHELTER')
          end

          it "maps 'notShelter' to 'NOT_CURRENTLY_IN_A_SHELTERED_ENVIRONMENT'" do
            form_attributes['veteran']['homelessness']['currentlyHomeless']['homelessSituationType'] =
              'notShelter'
            mapper.map_claim

            homeless_base = pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless]

            expect(homeless_base[:homelessSituationOptions]).to eq('NOT_CURRENTLY_IN_A_SHELTERED_ENVIRONMENT')
          end

          it "maps 'anotherPerson' to 'STAYING_WITH_ANOTHER_PERSON'" do
            form_attributes['veteran']['homelessness']['currentlyHomeless']['homelessSituationType'] =
              'anotherPerson'
            mapper.map_claim

            homeless_base = pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless]

            expect(homeless_base[:homelessSituationOptions]).to eq('STAYING_WITH_ANOTHER_PERSON')
          end

          it "maps 'other' to 'OTHER'" do
            form_attributes['veteran']['homelessness']['currentlyHomeless']['homelessSituationType'] =
              'other'
            mapper.map_claim

            homeless_base = pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless]

            expect(homeless_base[:homelessSituationOptions]).to eq('OTHER')
          end
        end
      end

      context 'riskOfBecomingHomeless attributes' do
        it 'maps the attributes if included' do
          form_attributes['veteran']['homelessness']['homelessnessRisk'] = {}
          form_attributes['veteran']['homelessness']['homelessnessRisk']['homelessnessRiskSituationType'] = 'other'
          form_attributes['veteran']['homelessness']['homelessnessRisk']['otherLivingSituation'] = 'Other situation'
          mapper.map_claim

          risk_of_homeless_base = pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless]

          expect(risk_of_homeless_base[:livingSituationOptions]).to eq('OTHER')
          expect(risk_of_homeless_base[:otherDescription]).to eq('Other situation')
        end

        it 'does not map anything if not included' do
          form_attributes['veteran']['homelessness']['homelessnessRisk'] = nil
          mapper.map_claim

          homeless_base = pdf_data[:data][:attributes][:homelessInformation]

          expect(homeless_base).not_to have_key(:riskOfBecomingHomeless)
        end

        context 'mapping the enums' do
          before do
            form_attributes['veteran']['homelessness']['homelessnessRisk'] = {}
            form_attributes['veteran']['homelessness']['homelessnessRisk']['otherLivingSituation'] = 'Other situation'
          end

          it "maps 'other' to 'OTHER'" do
            form_attributes['veteran']['homelessness']['homelessnessRisk']['homelessnessRiskSituationType'] = 'other'
            mapper.map_claim

            homeless_base = pdf_data[:data][:attributes][:homelessInformation]

            expect(homeless_base[:riskOfBecomingHomeless][:livingSituationOptions]).to eq('OTHER')
          end

          it "maps 'leavingShelter' to 'LEAVING_PUBLICLY_FUNDED_SYSTEM_OF_CARE'" do
            form_attributes['veteran']['homelessness']['homelessnessRisk']['homelessnessRiskSituationType'] =
              'leavingShelter'
            mapper.map_claim

            homeless_base = pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless]

            expect(homeless_base[:livingSituationOptions]).to eq('LEAVING_PUBLICLY_FUNDED_SYSTEM_OF_CARE')
          end

          it "maps 'losingHousing' to 'HOUSING_WILL_BE_LOST_IN_30_DAYS'" do
            form_attributes['veteran']['homelessness']['homelessnessRisk']['homelessnessRiskSituationType'] =
              'losingHousing'
            mapper.map_claim

            homeless_base = pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless]

            expect(homeless_base[:livingSituationOptions]).to eq('HOUSING_WILL_BE_LOST_IN_30_DAYS')
          end
        end
      end
    end

    context 'when homeless information is not included in the submission' do
      it 'adds nothing to the pdf data' do
        form_attributes['veteran']['homelessness'] = {}
        mapper.map_claim

        expect(pdf_data[:data][:attributes]).not_to have_key(:homelessInformation)
      end
    end
  end

  context 'section 5, disabilities' do
    let(:disabilities_object) do
      [
        {
          'disabilityActionType' => 'NEW',
          'name' => 'Arthritis',
          'serviceRelevance' => 'Caused by in-service injury'
        },
        {
          'disabilityActionType' => 'NEW',
          'name' => 'Left Knee Injury',
          'ratedDisabilityId' => '1100583',
          'diagnosticCode' => 9999,
          'approximateBeginDate' => '2018-04-02',
          'secondaryDisabilities' => [
            {
              'name' => 'Left Hip Pain',
              'disabilityActionType' => 'SECONDARY',
              'serviceRelevance' => 'Caused by a service-connected disability',
              'approximateBeginDate' => '2018-05-02'
            }
          ]
        }
      ]
    end

    it 'maps the attributes' do
      form_attributes['disabilities'] = disabilities_object
      mapper.map_claim

      disabilities_base = pdf_data[:data][:attributes][:claimInformation][:disabilities]

      expect(disabilities_base[0][:disability]).to eq('Arthritis')
      expect(disabilities_base[0][:serviceRelevance]).to eq('Caused by in-service injury')
      expect(disabilities_base[0]).not_to have_key(:approximateDate)
      expect(disabilities_base[1][:disability]).to eq('Left Knee Injury')
      expect(disabilities_base[1][:serviceRelevance]).to be_nil
      expect(disabilities_base[1][:approximateDate]).to eq('04/02/2018')
      expect(disabilities_base[2][:disability]).to eq('Left Hip Pain secondary to: Left Knee Injury')
      expect(disabilities_base[2][:serviceRelevance]).to eq('Caused by a service-connected disability')
      expect(disabilities_base[2][:approximateDate]).to eq('05/02/2018')
    end
  end

  describe 'section 5, treatment centers' do
    let(:treatments) do
      [
        {
          'startDate' => '2020-01-01',
          'endDate' => '2022-01-01',
          'treatedDisabilityNames' => [
            'Arthritis'
          ],
          'center' => {
            'name' => 'Private Facility Name',
            'country' => 'USA'
          }
        },
        {
          'startDate' => '2022-01',
          'treatedDisabilityNames' => [
            'Bad Knee'
          ],
          'center' => {
            'name' => 'Another Private Facility Name',
            'country' => 'USA'
          }
        },
        {
          'treatedDisabilityNames' => [
            'Bad Elbow'
          ],
          'center' => {
            'name' => 'Public Facility Name',
            'country' => 'USA'
          }
        }
      ]
    end

    context 'when treatments information is not provided' do
      before do
        @pdf_data = pdf_data
        @pdf_data[:data][:attributes][:claimInformation] = {}
      end

      it 'does not add any treatment key to the data object' do
        mapper.map_claim

        claim_information_base = pdf_data[:data][:attributes][:claimInformation]

        expect(claim_information_base).not_to have_key(:treatments)
      end
    end

    context 'when treatments information is provided' do
      it 'maps the attributes' do
        form_attributes['treatments'] = treatments
        mapper.map_claim

        treatments_base = pdf_data[:data][:attributes][:claimInformation][:treatments]

        expect(treatments_base[0][:treatmentDetails]).to eq('Arthritis - Private Facility Name, USA')
        expect(treatments_base[0][:dateOfTreatment]).to eq({ month: '01', year: '2020' })
        expect(treatments_base[0]).not_to have_key(:doNotHaveDate)
        expect(treatments_base[1][:treatmentDetails]).to eq('Bad Knee - Another Private Facility Name, USA')
        expect(treatments_base[1][:dateOfTreatment]).to eq({ month: '01', year: '2022' })
        expect(treatments_base[0]).not_to have_key(:doNotHaveDate)
        expect(treatments_base[2][:treatmentDetails]).to eq('Bad Elbow - Public Facility Name, USA')
        expect(treatments_base[2]).not_to have_key(:dateOfTreatment)
        expect(treatments_base[2][:doNotHaveDate]).to be(true)
      end
    end
  end

  context 'section 6, service information' do
    let(:service_periods_object) do
      [
        {
          'serviceBranch' => 'Navy',
          'activeDutyBeginDate' => '2015-11-14',
          'activeDutyEndDate' => '2018-11-30',
          'separationLocationCode' => '99876'
        },
        {
          'serviceBranch' => 'Army',
          'activeDutyBeginDate' => '2012-11-14',
          'activeDutyEndDate' => '2014-11-30'
        },
        {
          'serviceBranch' => 'Marines',
          'activeDutyBeginDate' => '2010-11-14',
          'activeDutyEndDate' => '2012-11-29',
          'separationLocationCode' => '99875'
        }
      ]
    end

    context 'service periods' do
      it 'maps the most recent service period attributes' do
        form_attributes['serviceInformation']['servicePeriods'] = service_periods_object
        mapper.map_claim

        service_period_base = pdf_data[:data][:attributes][:serviceInformation]

        expect(service_period_base[:branchOfService][:branch]).to eq('Navy')
        expect(service_period_base[:placeOfLastOrAnticipatedSeparation]).to eq('99876')
        expect(service_period_base[:mostRecentActiveService][:start]).to eq({ year: '2015', month: '11',
                                                                              day: '14' })
        expect(service_period_base[:mostRecentActiveService][:end]).to eq({ year: '2018', month: '11',
                                                                            day: '30' })
      end

      it 'maps the additional periods of service' do
        form_attributes['serviceInformation']['servicePeriods'] = service_periods_object
        mapper.map_claim

        service_period_base = pdf_data[:data][:attributes][:serviceInformation]

        expect(service_period_base).to have_key(:additionalPeriodsOfService)
        expect(service_period_base[:additionalPeriodsOfService][0][:start]).to eq({ year: '2012', month: '11',
                                                                                    day: '14' })
        expect(service_period_base[:additionalPeriodsOfService][0][:end]).to eq({ year: '2014', month: '11',
                                                                                  day: '30' })
        expect(service_period_base[:additionalPeriodsOfService][1][:start]).to eq({ year: '2010', month: '11',
                                                                                    day: '14' })
        expect(service_period_base[:additionalPeriodsOfService][1][:end]).to eq({ year: '2012', month: '11',
                                                                                  day: '29' })
      end
    end

    context 'confinements' do
      let(:confinement_periods) do
        [
          {
            'confinementBeginDate' => '2007-08-01',
            'confinementEndDate' => '2007-09-01'
          },
          {
            'confinementBeginDate' => '2007-11-01',
            'confinementEndDate' => '2007-12-01'
          }
        ]
      end

      it 'maps the confinement periods' do
        form_attributes['serviceInformation']['confinements'] = confinement_periods
        mapper.map_claim

        confinements_base = pdf_data[:data][:attributes][:serviceInformation][:prisonerOfWarConfinement]

        expect(confinements_base).to have_key(:confinementDates)
        expect(confinements_base[:confinementDates][0][:start]).to eq({ year: '2007', month: '08', day: '01' })
        expect(confinements_base[:confinementDates][0][:end]).to eq({ year: '2007', month: '09', day: '01' })
        expect(confinements_base[:confinementDates][1][:start]).to eq({ year: '2007', month: '11', day: '01' })
        expect(confinements_base[:confinementDates][1][:end]).to eq({ year: '2007', month: '12', day: '01' })
      end
    end

    context 'reserves national guard service' do
      let(:reserves) do
        {
          'title10Activation' => {
            'anticipatedSeparationDate' => '2025-12-01',
            'title10ActivationDate' => '2023-01-01'
          },
          'obligationTermOfServiceFromDate' => '2023-01-01',
          'obligationTermOfServiceToDate' => '2023-12-01',
          'unitName' => 'Unit Name',
          'unitPhone' => {
            'areaCode' => '123',
            'phoneNumber' => '1231234'
          },
          'receivingInactiveDutyTrainingPay' => false
        }
      end

      it 'maps the required attributes when reserves is present' do
        form_attributes['serviceInformation']['reservesNationalGuardService'] = reserves
        mapper.map_claim

        reserves_base = pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService]

        expect(reserves_base).not_to be_nil
        expect(reserves_base[:unitName]).to eq('Unit Name')
        expect(reserves_base[:obligationTermsOfService][:start]).to eq({ year: '2023', month: '01', day: '01' })
        expect(reserves_base[:obligationTermsOfService][:end]).to eq({ year: '2023', month: '12', day: '01' })
      end

      it 'maps the optional attributes when present' do
        form_attributes['serviceInformation']['reservesNationalGuardService'] = reserves
        mapper.map_claim

        reserves_base = pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService]
        service_info_base = pdf_data[:data][:attributes][:serviceInformation]

        expect(reserves_base[:unitPhoneNumber]).to eq('1231231234')
        expect(reserves_base[:receivingInactiveDutyTrainingPay]).to be('NO')
        expect(service_info_base[:federalActivation][:activationDate]).to eq({ year: '2023', month: '01', day: '01' })
        expect(service_info_base[:federalActivation][:anticipatedSeparationDate]).to eq({ year: '2025', month: '12',
                                                                                          day: '01' })
      end
    end

    context 'alternate names' do
      let(:alternate_names_data) do
        [
          {
            'firstName' => 'Jane',
            'lastName' => 'Doe'
          },
          {
            'firstName' => 'January',
            'middleName' => 'E',
            'lastName' => 'Doe'
          },
          {
            'firstName' => 'J'
          }
        ]
      end

      it 'maps the alternate names' do
        form_attributes['serviceInformation']['alternateNames'] = alternate_names_data
        mapper.map_claim

        alt_names_base = pdf_data[:data][:attributes][:serviceInformation][:alternateNames]

        expect(alt_names_base[0]).to eq('Jane Doe')
        expect(alt_names_base[1]).to eq('January E Doe')
        expect(alt_names_base[2]).to eq('J')
      end

      it 'handles as expected when no alternate names are included' do
        form_attributes['serviceInformation']['alternateNames'] = nil
        mapper.map_claim

        service_info_base = pdf_data[:data][:attributes][:serviceInformation]

        expect(service_info_base).not_to have_key(:alternateNames)
      end
    end
  end

  context 'section 7 service pay' do
    let(:service_pay_data) do
      {
        'waiveVABenefitsToRetainTrainingPay' => false,
        'waiveVABenefitsToRetainRetiredPay' => false,
        'militaryRetiredPay' => {
          'receiving' => true,
          'payment' => {
            'serviceBranch' => 'Air Force',
            'amount' => 500
          },
          'willReceiveInFuture' => true,
          'futurePayExplanation' => 'Future payment explanation'
        },
        'separationPay' => {
          'received' => false,
          'payment' => {
            'serviceBranch' => 'Marine Corps',
            'amount' => 2000
          },
          'receivedDate' => '1990-02-01'
        }
      }
    end

    let(:min_service_pay_data) do
      {
        'waiveVABenefitsToRetainTrainingPay' => true,
        'waiveVABenefitsToRetainRetiredPay' => true
      }
    end

    it 'maps nothing if not included on the submission' do
      form_attributes['service_pay'] = nil
      mapper.map_claim

      claim_data_base = pdf_data[:data][:attributes]

      expect(claim_data_base).not_to have_key(:servicePay)
    end

    it 'maps the attributes' do
      form_attributes['servicePay'] = service_pay_data
      mapper.map_claim

      service_pay_base = pdf_data[:data][:attributes][:servicePay]
      service_pay_military_pay_base = pdf_data[:data][:attributes][:servicePay][:militaryRetiredPay]
      separation_pay_base = pdf_data[:data][:attributes][:servicePay][:separationSeverancePay]

      expect(service_pay_base).not_to be_nil
      expect(service_pay_base[:favorTrainingPay]).to be(false)
      expect(service_pay_base[:favorMilitaryRetiredPay]).to be(false)
      expect(service_pay_base[:receivingMilitaryRetiredPay]).to be('YES')
      expect(service_pay_base[:futureMilitaryRetiredPay]).to be('YES')
      expect(service_pay_base[:futureMilitaryRetiredPayExplanation]).to eq('Future payment explanation')
      expect(service_pay_military_pay_base[:branchOfService][:branch]).to eq('Air Force')
      expect(service_pay_military_pay_base[:monthlyAmount]).to eq(500)
      expect(service_pay_base[:receivedSeparationOrSeverancePay]).to be('NO')
      expect(separation_pay_base[:datePaymentReceived]).to eq({ year: '1990', month: '02', day: '01' })
      expect(separation_pay_base[:branchOfService][:branch]).to eq('Marine Corps')
      expect(separation_pay_base[:preTaxAmountReceived]).to eq(2000)
    end

    it 'maps the attributes with a minimum request' do
      form_attributes['servicePay'] = min_service_pay_data
      mapper.map_claim

      service_pay_base = pdf_data[:data][:attributes][:servicePay]

      expect(service_pay_base).not_to be_nil
      expect(service_pay_base[:favorTrainingPay]).to be(true)
      expect(service_pay_base[:favorMilitaryRetiredPay]).to be(true)
    end
  end

  context 'section 8 direct deposit' do
    let(:direct_deposit_data) do
      {
        'accountType' => 'CHECKING',
        'accountNumber' => '123123123123',
        'routingNumber' => '123123123',
        'bankName' => 'ABC Bank'
      }
    end

    let(:min_direct_deposit_data) do
      {
        'accountType' => 'SAVINGS',
        'accountNumber' => '123123123124',
        'routingNumber' => '123123124'
      }
    end

    it 'maps nothing if not included on the submission' do
      form_attributes['directDeposit'] = nil
      mapper.map_claim

      claim_data_base = pdf_data[:data][:attributes]

      expect(claim_data_base).not_to have_key(:directDepositInformation)
    end

    it 'maps the attributes' do
      form_attributes['directDeposit'] = direct_deposit_data
      mapper.map_claim

      direct_deposit_base = pdf_data[:data][:attributes][:directDepositInformation]

      expect(direct_deposit_base).not_to be_nil
      expect(direct_deposit_base[:accountType]).to eq('CHECKING')
      expect(direct_deposit_base[:accountNumber]).to eq('123123123123')
      expect(direct_deposit_base[:routingNumber]).to eq('123123123')
      expect(direct_deposit_base[:financialInstitutionName]).to eq('ABC Bank')
    end

    it 'handles mapping optional attributes' do
      form_attributes['directDeposit'] = min_direct_deposit_data
      mapper.map_claim

      direct_deposit_base = pdf_data[:data][:attributes][:directDepositInformation]
      expect(direct_deposit_base[:accountType]).to eq('SAVINGS')
      expect(direct_deposit_base[:accountNumber]).to eq('123123123124')
      expect(direct_deposit_base[:routingNumber]).to eq('123123124')
      expect(direct_deposit_base).not_to have_key(:financialInstitutionName)
    end
  end

  context 'section 9 claim date and signature' do
    let(:claim_date_data) { '2018-08-28T19:53:45+00:00' }
    let(:first_name) { auth_headers['va_eauth_firstName'] }
    let(:last_name) { auth_headers['va_eauth_lastName'] }
    let(:created_at_object) do
      {
        year: created_at.strftime('%Y').to_s,
        month: created_at.strftime('%m').to_s,
        day: created_at.strftime('%d').to_s
      }
    end

    it 'maps the attributes' do
      form_attributes['claimDate'] = claim_date_data
      mapper.map_claim

      claim_cert_base = pdf_data[:data][:attributes][:claimCertificationAndSignature]

      expect(claim_cert_base[:dateSigned]).to eq({ year: '2018', month: '08', day: '28' })
      expect(claim_cert_base[:signature]).not_to be_nil
    end

    it 'maps claimDate correctly if not provided' do
      form_attributes['claimDate'] = nil
      mapper.map_claim

      claim_cert_base = pdf_data[:data][:attributes][:claimCertificationAndSignature]

      expect(claim_cert_base[:dateSigned]).to eq(created_at_object)
      expect(claim_cert_base[:signature]).not_to be_nil
    end
  end

  describe '#extract_date_safely' do
    it 'uses a date with timezone offset' do
      res = mapper.send(:extract_date_safely, '2018-08-28T19:53:45+00:00')

      expect(res).to eq('2018-08-28')
    end

    it 'uses a date with just UTC indicator' do
      res = mapper.send(:extract_date_safely, '2023-12-31T23:59:59Z')

      expect(res).to eq('2023-12-31')
    end

    it 'uses a date in YYYY-MM-DD pattern' do
      res = mapper.send(:extract_date_safely, '2020-11-22')

      expect(res).to eq('2020-11-22')
    end
  end

  describe '#valid_date?' do
    it 'returns false an invalid date' do
      res = mapper.send(:valid_date?, '2024-13-15')

      expect(res).to be(false)
    end

    it 'returns true a valid date' do
      res = mapper.send(:valid_date?, '2024-09-15')

      expect(res).to be(true)
    end
  end
end
