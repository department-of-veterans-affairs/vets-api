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
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:middle_initial) { 'L' }

  let(:mapper) do
    ClaimsApi::V1::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, auth_headers, middle_initial)
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

  describe '#set_pdf_data_for_section_one' do
    context 'when identificationInformation key does not exist' do
      it 'sets the identificationInformation key to an empty hash' do
        res = mapper.send(:set_pdf_data_for_section_one)

        expect(res).to eq({})
      end
    end

    context 'when identificationInformation key already exists' do
      before do
        @pdf_data = pdf_data
        @pdf_data[:data][:attributes][:identificationInformation] = {}
      end

      it 'returns early without modifying the existing data' do
        res = mapper.send(:set_pdf_data_for_section_one)

        expect(res).to be_nil
      end
    end
  end

  describe '#set_pdf_data_for_mailing_address' do
    context 'when mailingAddress key does not exist' do
      before do
        @pdf_data = pdf_data
        @pdf_data[:data][:attributes][:identificationInformation] = {}
      end

      it 'sets the mailingAddress key to an empty hash' do
        res = mapper.send(:set_pdf_data_for_mailing_address)

        expect(res).to eq({})
      end
    end

    context 'when mailingAddress key already exists' do
      before do
        @pdf_data = pdf_data
        @pdf_data[:data][:attributes][:identificationInformation] = {}
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress] = {}
      end

      it 'returns early without modifying the existing data' do
        res = mapper.send(:set_pdf_data_for_mailing_address)

        expect(res).to be_nil
      end
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
    describe '#set_pdf_data_for_homeless_information' do
      context 'when homelessInformation key does not exist' do
        before do
          @pdf_data = pdf_data
        end

        it 'sets the homelessInformation key to an empty hash' do
          res = mapper.send(:set_pdf_data_for_homeless_information)

          expect(res).to eq({})
        end
      end

      context 'when homelessInformation key already exists' do
        before do
          @pdf_data = pdf_data
          @pdf_data[:data][:attributes][:homelessInformation] = {}
        end

        it 'returns early without modifying the existing data' do
          res = mapper.send(:set_pdf_data_for_homeless_information)

          expect(res).to be_nil
        end
      end
    end

    context 'when homeless information is included in the submission' do
      context 'pointOfContact attributes' do
        it 'maps the attributes if included' do
          mapper.map_claim

          homeless_base = pdf_data[:data][:attributes][:homelessInformation]

          expect(homeless_base[:pointOfContact]).to eq('Firstname Lastname')
          expect(homeless_base[:pointOfContactNumber]).to eq('123-555-1234')
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
        describe '#set_pdf_data_for_currently_homeless_information' do
          context 'when currentlyHomeless key does not exist' do
            before do
              @pdf_data = pdf_data
              @pdf_data[:data][:attributes][:homelessInformation] = {}
            end

            it 'sets the currentlyHomeless key to an empty hash' do
              res = mapper.send(:set_pdf_data_for_currently_homeless_information)

              expect(res).to eq({})
            end
          end

          context 'when currentlyHomeless key already exists' do
            before do
              @pdf_data = pdf_data
              @pdf_data[:data][:attributes][:homelessInformation] = {}
              @pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless] = {}
            end

            it 'returns early without modifying the existing data' do
              res = mapper.send(:set_pdf_data_for_currently_homeless_information)

              expect(res).to be_nil
            end
          end
        end

        it 'maps the attributes if included' do
          mapper.map_claim

          currently_homeless_base = pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless]

          expect(currently_homeless_base[:homelessSituationOptions]).to eq('fleeing')
          expect(currently_homeless_base[:otherDescription]).to eq('none')
        end

        it 'does not map anything if not included' do
          form_attributes['veteran']['homelessness']['currentlyHomeless'] = nil
          mapper.map_claim

          homeless_base = pdf_data[:data][:attributes][:homelessInformation]

          expect(homeless_base).not_to have_key(:currentlyHomeless)
        end
      end

      context 'riskOfBecomingHomeless attributes' do
        describe '#set_pdf_data_for_homelessness_risk_information' do
          context 'when riskOfBecomingHomeless key does not exist' do
            before do
              @pdf_data = pdf_data
              @pdf_data[:data][:attributes][:homelessInformation] = {}
            end

            it 'sets the riskOfBecomingHomeless key to an empty hash' do
              res = mapper.send(:set_pdf_data_for_homelessness_risk_information)

              expect(res).to eq({})
            end
          end

          context 'when riskOfBecomingHomeless key already exists' do
            before do
              @pdf_data = pdf_data
              @pdf_data[:data][:attributes][:homelessInformation] = {}
              @pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless] = {}
            end

            it 'returns early without modifying the existing data' do
              res = mapper.send(:set_pdf_data_for_homelessness_risk_information)

              expect(res).to be_nil
            end
          end
        end

        it 'maps the attributes if included' do
          form_attributes['veteran']['homelessness']['homelessnessRisk'] = {}
          form_attributes['veteran']['homelessness']['homelessnessRisk']['homelessnessRiskSituationType'] = 'other'
          form_attributes['veteran']['homelessness']['homelessnessRisk']['otherLivingSituation'] = 'Other situation'
          mapper.map_claim

          risk_of_homeless_base = pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless]

          expect(risk_of_homeless_base[:livingSituationOptions]).to eq('other')
          expect(risk_of_homeless_base[:otherDescription]).to eq('Other situation')
        end

        it 'does not map anything if not included' do
          form_attributes['veteran']['homelessness']['homelessnessRisk'] = nil
          mapper.map_claim

          homeless_base = pdf_data[:data][:attributes][:homelessInformation]

          expect(homeless_base).not_to have_key(:riskOfBecomingHomeless)
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

    describe '#set_pdf_data_for_claim_information' do
      context 'when the claimInformation key does not exist' do
        before do
          @pdf_data = pdf_data
        end

        it 'sets the claimInformation key to an empty hash' do
          res = mapper.send(:set_pdf_data_for_claim_information)

          expect(res).to eq({})
        end
      end

      context 'when the claimInformation key already exists' do
        before do
          @pdf_data = pdf_data
          @pdf_data[:data][:attributes][:claimInformation] = {}
        end

        it 'returns early without modifying the existing data' do
          res = mapper.send(:set_pdf_data_for_claim_information)

          expect(res).to be_nil
        end
      end
    end

    describe '#set_pdf_data_for_disabilities' do
      context 'when the disabilities key does not exist' do
        before do
          @pdf_data = pdf_data
          @pdf_data[:data][:attributes][:claimInformation] = {}
        end

        it 'sets the disabilities key to an empty hash' do
          res = mapper.send(:set_pdf_data_for_disabilities)

          expect(res).to eq({})
        end
      end

      context 'when the disabilities key already exists' do
        before do
          @pdf_data = pdf_data
          @pdf_data[:data][:attributes][:claimInformation] = {}
          @pdf_data[:data][:attributes][:claimInformation][:disabilities] = {}
        end

        it 'returns early without modifying the existing data' do
          res = mapper.send(:set_pdf_data_for_disabilities)

          expect(res).to be_nil
        end
      end
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
          'startDate' => '2022-01-12',
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

    describe '#set_pdf_data_for_claim_information' do
      context 'when the claimInformation key does not exist' do
        before do
          @pdf_data = pdf_data
        end

        it 'sets the claimInformation key to an empty hash' do
          res = mapper.send(:set_pdf_data_for_claim_information)

          expect(res).to eq({})
        end
      end

      context 'when the claimInformation key already exists' do
        before do
          @pdf_data = pdf_data
          @pdf_data[:data][:attributes][:claimInformation] = {}
        end

        it 'returns early without modifying the existing data' do
          res = mapper.send(:set_pdf_data_for_claim_information)

          expect(res).to be_nil
        end
      end
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

        expect(treatments_base[0][:treatment_details]).to eq('Arthritis - Private Facility Name, USA')
        expect(treatments_base[0][:dateOfTreatment]).to eq({ year: '2020', month: '01', day: '01' })
        expect(treatments_base[0]).not_to have_key(:doNotHaveDate)
        expect(treatments_base[1][:treatment_details]).to eq('Bad Knee - Another Private Facility Name, USA')
        expect(treatments_base[1][:dateOfTreatment]).to eq({ month: '01', year: '2022' })
        expect(treatments_base[0]).not_to have_key(:doNotHaveDate)
        expect(treatments_base[2][:treatment_details]).to eq('Bad Elbow - Public Facility Name, USA')
        expect(treatments_base[2]).not_to have_key(:dateOfTreatment)
        expect(treatments_base[2][:doNotHaveDate]).to be(true)
      end
    end
  end
end
