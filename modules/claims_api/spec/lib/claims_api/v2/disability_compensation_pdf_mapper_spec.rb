# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_pdf_mapper'

describe ClaimsApi::V2::DisabilityCompensationPdfMapper do
  describe '526 claim maps to the pdf generator', vcr: 'claims_api/disability_comp' do
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
          'v2',
          'veterans',
          'disability_compensation',
          'form_526_json_api.json'
        ).read
      )
    end

    let(:user) { FactoryBot.create(:user, :loa3) }
    let(:auth_headers) do
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    end

    let(:middle_initial) { 'L' }
    let(:created_at) { Timecop.freeze(Time.zone.now) }
    let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }

    let(:mapper) do
      ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, auth_headers, middle_initial,
                                                         created_at)
    end

    context '526 section 0, claim attributes' do
      it 'maps the attributes correctly' do
        mapper.map_claim

        claim_process_type = pdf_data[:data][:attributes][:claimProcessType]
        claim_notes = pdf_data[:data][:attributes][:overflowText]

        expect(claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
        expect(claim_notes).to eq('Some things that are important to know, and are not included in any other place.')
      end

      describe 'when the claimProcessType is BDD_PROGRAM' do
        date = DateTime.now + 4.months
        let(:claim_process_type) { 'BDD_PROGRAM' }
        let(:anticipated_seperation_date) { date.strftime('%Y-%m-%d') }
        let(:active_duty_end_date) { date.strftime('%Y-%m-%d') }

        it 'maps correctly to BDD_PROGRAM_CLAIM' do
          form_attributes['claimProcessType'] = claim_process_type
          mapper.map_claim

          claim_process_type = pdf_data[:data][:attributes][:claimProcessType]
          expect(claim_process_type).to eq('BDD_PROGRAM_CLAIM')
        end

        it 'maps anticipatedSeparationDate correctly' do
          form_attributes['claimProcessType'] = claim_process_type
          form_attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] =
            anticipated_seperation_date
          mapper.map_claim

          date_of_release_from_active_duty =
            pdf_data[:data][:attributes][:identificationInformation][:dateOfReleaseFromActiveDuty]
          expect(date_of_release_from_active_duty).to eq({ year: date.strftime('%Y'), month: date.strftime('%m'),
                                                           day: date.strftime('%d') })
        end

        it 'maps activeDutyEndDate correctly' do
          form_attributes['claimProcessType'] = claim_process_type
          form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = active_duty_end_date
          mapper.map_claim

          date_of_release_from_active_duty =
            pdf_data[:data][:attributes][:identificationInformation][:dateOfReleaseFromActiveDuty]
          expect(date_of_release_from_active_duty).to eq({ year: date.strftime('%Y'), month: date.strftime('%m'),
                                                           day: date.strftime('%d') })
        end

        it 'maps activeDutyEndDate correctly when federalActivation & activeDutyBeginDate are nil' do
          form_attributes['claimProcessType'] = claim_process_type
          form_attributes['serviceInformation']['federalActivation'] = nil
          form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyBeginDate'] = nil
          form_attributes['serviceInformation']['servicePeriods'][0]['activeDutyEndDate'] = active_duty_end_date
          mapper.map_claim

          date_of_release_from_active_duty =
            pdf_data[:data][:attributes][:identificationInformation][:dateOfReleaseFromActiveDuty]
          expect(date_of_release_from_active_duty).to eq({ year: date.strftime('%Y'), month: date.strftime('%m'),
                                                           day: date.strftime('%d') })
        end
      end

      context 'with empty confinements' do
        it "doesn't send confinements" do
          form_attributes['serviceInformation']['confinements'] = []
          mapper.map_claim

          service_information = pdf_data[:data][:attributes][:serviceInformation]
          expect(service_information.keys).not_to include :confinements
        end
      end
    end

    context '526 section 1' do
      let(:birls_file_number) { auth_headers['va_eauth_birlsfilenumber'] }

      it 'maps the mailing address' do
        mapper.map_claim

        number_and_street = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:numberAndStreet]
        apartment_or_unit_number =
          pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:apartmentOrUnitNumber]
        city = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:city]
        country = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country]
        zip = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:zip]
        state = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:state]
        expect(number_and_street).to eq('1234 Couch Street Unit 4 Room 1')
        expect(apartment_or_unit_number).to eq(nil)
        expect(city).to eq('Portland')
        expect(country).to eq('US')
        expect(zip).to eq('41726-1234')
        expect(state).to eq('OR')
      end

      it 'maps the other veteran info' do
        mapper.map_claim

        current_va_employee = pdf_data[:data][:attributes][:identificationInformation][:currentVaEmployee]
        ssn = pdf_data[:data][:attributes][:identificationInformation][:ssn]
        name = pdf_data[:data][:attributes][:identificationInformation][:name]
        birth_date = pdf_data[:data][:attributes][:identificationInformation][:dateOfBirth]
        va_file_number = pdf_data[:data][:attributes][:identificationInformation][:vaFileNumber]
        email = pdf_data[:data][:attributes][:identificationInformation][:emailAddress][:email]
        agree_to_email =
          pdf_data[:data][:attributes][:identificationInformation][:emailAddress][:agreeToEmailRelatedToClaim]
        telephone = pdf_data[:data][:attributes][:identificationInformation][:phoneNumber][:telephone]
        international_telephone =
          pdf_data[:data][:attributes][:identificationInformation][:phoneNumber][:internationalTelephone]

        expect(ssn).to eq('796-11-1863')
        expect(name).to eq({ lastName: 'lincoln', middleInitial: 'L', firstName: 'abraham' })
        expect(birth_date).to eq({ month: '02', day: '12', year: '1809' })
        expect(current_va_employee).to eq(false)
        expect(va_file_number).to eq(birls_file_number)
        expect(email).to eq('valid@somedomain.com')
        expect(agree_to_email).to eq(true)
        expect(telephone).to eq('555-555-5555')
        expect(international_telephone).to eq('44-20-1234-5678')
      end

      it 'maps veteran info correctly with a nil phone number' do
        form_attributes['veteranIdentification']['veteranNumber']['telephone'] = nil
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:identificationInformation][:phoneNumber]
        expected = { internationalTelephone: '44-20-1234-5678' }
        expect(actual).to eq(expected)
      end

      it 'maps veteran info correctly with a nil international phone number' do
        form_attributes['veteranIdentification']['veteranNumber']['internationalTelephone'] = nil
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:identificationInformation][:phoneNumber]
        expected = { telephone: '555-555-5555' }
        expect(actual).to eq(expected)
      end

      it 'maps veteran info correctly with an empty phone object' do
        form_attributes['veteranIdentification']['veteranNumber']['internationalTelephone'] = nil
        form_attributes['veteranIdentification']['veteranNumber']['telephone'] = nil
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:identificationInformation][:phoneNumber]
        expect(actual).to eq(nil)
      end
    end

    context '526 section 2, change of address' do
      it 'maps the dates' do
        mapper.map_claim
        begin_date = pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:start]
        end_date = pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:end]
        type_of_addr_change = pdf_data[:data][:attributes][:changeOfAddress][:typeOfAddressChange]
        number_and_street = pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:numberAndStreet]
        apartment_or_unit_number =
          pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:apartmentOrUnitNumber]
        city = pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:city]
        country = pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:country]
        zip = pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:zip]
        state = pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:state]

        expect(begin_date).to eq({ month: '06', day: '04', year: '2023' })
        expect(end_date).to eq({ month: '12', day: '04', year: '2023' })
        expect(type_of_addr_change).to eq('TEMPORARY')
        expect(number_and_street).to eq('10 Peach St Unit 4 Room 1')
        expect(apartment_or_unit_number).to eq(nil)
        expect(city).to eq('Atlanta')
        expect(country).to eq('US')
        expect(zip).to eq('42220-9897')
        expect(state).to eq('GA')
      end
    end

    context '526 section 3, homelessness' do
      it 'maps the homeless_point_of_contact' do
        mapper.map_claim

        homeless_point_of_contact = pdf_data[:data][:attributes][:homelessInformation][:pointOfContact]
        homeless_telephone = pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber][:telephone]
        homeless_international_telephone =
          pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber][:internationalTelephone]
        homeless_currently = pdf_data[:data][:attributes][:homelessInformation][:areYouCurrentlyHomeless]
        homeless_situation_options =
          pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless][:homelessSituationOptions]
        homeless_currently_other_description =
          pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless][:otherDescription]

        expect(homeless_point_of_contact).to eq('john stewart')
        expect(homeless_telephone).to eq('555-555-5555')
        expect(homeless_international_telephone).to eq('44-20-1234-5678')
        expect(homeless_currently).to eq('YES') # can't be both homess & at risk
        expect(homeless_situation_options).to eq('FLEEING_CURRENT_RESIDENCE')
        expect(homeless_currently_other_description).to eq('ABCDEFGHIJKLM')
      end

      it 'maps homeless info correctly with a nil phone number' do
        form_attributes['homeless']['pointOfContactNumber']['telephone'] = nil
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber]
        expected = { internationalTelephone: '44-20-1234-5678' }
        expect(actual).to eq(expected)
      end

      it 'maps homeless info correctly with a nil international phone number' do
        form_attributes['homeless']['pointOfContactNumber']['internationalTelephone'] = nil
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber]
        expected = { telephone: '555-555-5555' }
        expect(actual).to eq(expected)
      end

      it 'maps homeless info correctly with an empty phone object' do
        form_attributes['homeless']['pointOfContactNumber']['internationalTelephone'] = nil
        form_attributes['homeless']['pointOfContactNumber']['telephone'] = nil
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber]
        expect(actual).to eq(nil)
      end
    end

    context '526 section 4, toxic exposure' do
      it 'maps the attributes correctly' do
        mapper.map_claim

        toxic_exp_data = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]

        gulf_locations = toxic_exp_data[:gulfWarHazardService][:servedInGulfWarHazardLocations]
        gulf_begin_date = toxic_exp_data[:gulfWarHazardService][:serviceDates][:start]
        gulf_end_date = toxic_exp_data[:gulfWarHazardService][:serviceDates][:end]

        herbicide_locations = toxic_exp_data[:herbicideHazardService][:servedInHerbicideHazardLocations]
        other_locations = toxic_exp_data[:herbicideHazardService][:otherLocationsServed]
        herb_begin_date = toxic_exp_data[:herbicideHazardService][:serviceDates][:start]
        herb_end_date = toxic_exp_data[:herbicideHazardService][:serviceDates][:end]

        additional_exposures = toxic_exp_data[:additionalHazardExposures][:additionalExposures]
        specify_other_exp = toxic_exp_data[:additionalHazardExposures][:specifyOtherExposures]
        exp_begin_date = toxic_exp_data[:additionalHazardExposures][:exposureDates][:start]
        exp_end_date = toxic_exp_data[:additionalHazardExposures][:exposureDates][:end]

        multi_exp_begin_date = toxic_exp_data[:multipleExposures][0][:exposureDates][:start]
        multi_exp_end_date = toxic_exp_data[:multipleExposures][0][:exposureDates][:end]
        multi_exp_location = toxic_exp_data[:multipleExposures][0][:exposureLocation]
        multi_exp_hazard = toxic_exp_data[:multipleExposures][0][:hazardExposedTo]

        expect(gulf_locations).to eq('YES')
        expect(gulf_begin_date).to eq({ month: '07', year: '2018' })
        expect(gulf_end_date).to eq({ month: '08', year: '2018' })

        expect(herbicide_locations).to eq('YES')
        expect(other_locations).to eq('ABCDEFGHIJKLM')
        expect(herb_begin_date).to eq({ month: '07', year: '2018' })
        expect(herb_end_date).to eq({ month: '08', year: '2018' })

        expect(additional_exposures).to eq(%w[ASBESTOS SHIPBOARD_HAZARD_AND_DEFENSE])
        expect(specify_other_exp).to eq('Other exposure details')
        expect(exp_begin_date).to eq({ month: '07', year: '2018' })
        expect(exp_end_date).to eq({ month: '08', year: '2018' })

        expect(multi_exp_begin_date).to eq({ month: '12', year: '2012' })
        expect(multi_exp_end_date).to eq({ month: '07', year: '2013' })
        expect(multi_exp_location).to eq('Guam')
        expect(multi_exp_hazard).to eq('RADIATION')
      end

      it 'maps herbicide correctly when nothing is included' do
        form_attributes['toxicExposure']['herbicideHazardService'] = nil
        mapper.map_claim

        herb_exp_data = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:herbicideHazardService]
        expect(herb_exp_data).to eq(nil)
      end

      it 'maps herbicide correctly when dates are not included' do
        form_attributes['toxicExposure']['herbicideHazardService']['serviceDates'] = nil

        mapper.map_claim

        toxic_exp_data = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
        herb_service_dates = toxic_exp_data[:herbicideHazardService][:serviceDates]

        expect(herb_service_dates).to eq(nil)
      end

      it 'maps additional exposures correctly when nothing is included' do
        form_attributes['toxicExposure']['additionalHazardExposures'] = nil
        mapper.map_claim

        add_exp_data = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure][:additionalHazardExposures]
        expect(add_exp_data).to eq(nil)
      end

      it 'maps additional exposures correctly when dates are not included' do
        form_attributes['toxicExposure']['additionalHazardExposures']['exposureDates'] = nil

        mapper.map_claim

        toxic_exp_data = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
        additional_exposure_dates = toxic_exp_data[:additionalHazardExposures][:exposureDates]

        expect(additional_exposure_dates).to eq(nil)
      end

      context "526 section 4, herbicideHazardService.servedInHerbicideHazardLocations exposures can answer 'NO'" do
        it 'maps the attributes correctly' do
          toxic_exp_data = form_attributes['toxicExposure']
          toxic_exp_data['herbicideHazardService']['serviceDates']['beginDate'] = nil
          toxic_exp_data['herbicideHazardService']['serviceDates']['endDate'] = nil
          toxic_exp_data['herbicideHazardService']['servedInHerbicideHazardLocations'] = 'NO'
          toxic_exp_data['herbicideHazardService']['otherLocationsServed'] = nil

          mapper.map_claim

          exposure_info = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
          expect(exposure_info[:herbicideHazardService][:servedInHerbicideHazardLocations]).to eq('NO')
        end
      end

      context '526 section 4, gulfWarHazardService exposures null data' do
        it 'maps the attributes correctly' do
          toxic_exp_data = form_attributes['toxicExposure']
          toxic_exp_data['gulfWarHazardService']['serviceDates']['beginDate'] = nil
          toxic_exp_data['gulfWarHazardService']['serviceDates']['endDate'] = nil
          toxic_exp_data['gulfWarHazardService']['servedInGulfWarHazardLocations'] = nil

          mapper.map_claim

          exposure_info = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
          expect(exposure_info[:gulfWarHazardService]).to eq(nil)
        end
      end

      context '526 section 4, herbicideHazardService exposures null data' do
        it 'maps the attributes correctly' do
          toxic_exp_data = form_attributes['toxicExposure']
          toxic_exp_data['herbicideHazardService']['serviceDates']['beginDate'] = nil
          toxic_exp_data['herbicideHazardService']['serviceDates']['endDate'] = nil
          toxic_exp_data['herbicideHazardService']['servedInHerbicideHazardLocations'] = nil
          toxic_exp_data['herbicideHazardService']['otherLocationsServed'] = nil

          mapper.map_claim

          exposure_info = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
          expect(exposure_info[:herbicideHazardService]).to eq(nil)
        end
      end

      context '526 section 4, additionalHazardExposures null data' do
        it 'maps the attributes correctly' do
          toxic_exp_data = form_attributes['toxicExposure']
          toxic_exp_data['additionalHazardExposures']['exposureDates']['beginDate'] = nil
          toxic_exp_data['additionalHazardExposures']['exposureDates']['endDate'] = nil
          toxic_exp_data['additionalHazardExposures']['additionalExposures'] = nil
          toxic_exp_data['additionalHazardExposures']['specifyOtherExposures'] = nil

          mapper.map_claim

          exposure_info = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
          expect(exposure_info[:additionalHazardExposures]).to eq(nil)
        end
      end

      context '526 section 4, multiple exposures null data' do
        it 'maps the attributes correctly' do
          toxic_exp_data = form_attributes['toxicExposure']
          toxic_exp_data['multipleExposures'][0]['exposureDates']['beginDate'] = nil
          toxic_exp_data['multipleExposures'][0]['exposureDates']['endDate'] = nil
          toxic_exp_data['multipleExposures'][0]['exposureLocation'] = nil
          toxic_exp_data['multipleExposures'][0]['hazardExposedTo'] = nil

          mapper.map_claim

          exposure_info = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
          expect(exposure_info[:multipleExposures]).to eq(nil)
        end
      end

      context '526 section 4, multiple exposures null endDate' do
        it 'maps the attributes correctly' do
          toxic_exp_data = form_attributes['toxicExposure']
          toxic_exp_data['multipleExposures'][0]['exposureDates']['endDate'] = nil

          mapper.map_claim

          exposure_info = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
          expect(exposure_info[:multipleExposures][0][:exposureLocation]).to eq('Guam')
          expect(exposure_info[:multipleExposures][0][:hazardExposedTo]).to eq('RADIATION')
          expect(exposure_info[:multipleExposures][0][:exposureDates][:start][:month]).to eq('12')
          expect(exposure_info[:multipleExposures][0][:exposureDates][:start][:year]).to eq('2012')
        end
      end

      context '526 section 4, gulfWarHazardService' do
        it "does not default to 'NO'" do
          toxic_exp_data = form_attributes['toxicExposure']['gulfWarHazardService']
          toxic_exp_data['servedInGulfWarHazardLocations'] = nil

          mapper.map_claim

          exposure_info = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
          expect(exposure_info[:gulfWarHazardService][:servedInGulfWarHazardLocations]).to eq(nil)
        end
      end

      context '526 section 4, herbicideHazardService' do
        it "does not default to 'NO'" do
          toxic_exp_data = form_attributes['toxicExposure']['herbicideHazardService']
          toxic_exp_data['servedInHerbicideHazardLocations'] = nil

          mapper.map_claim

          exposure_info = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]
          expect(exposure_info[:herbicideHazardService][:servedInHerbicideHazardLocations]).to eq(nil)
        end
      end
    end

    context '526 section 5, claimInfo: diabilities' do
      it 'maps the attributes correctly' do
        mapper.map_claim

        claim_info = pdf_data[:data][:attributes][:claimInformation]

        name = claim_info[:disabilities][0][:disability]
        relevance = claim_info[:disabilities][0][:serviceRelevance]
        date = claim_info[:disabilities][0][:approximateDate]
        event = claim_info[:disabilities][0][:exposureOrEventOrInjury]
        attribut_count = claim_info[:disabilities][0].count
        secondary_name = claim_info[:disabilities][1][:disability]
        secondary_event = claim_info[:disabilities][1][:exposureOrEventOrInjury]
        secondary_relevance = claim_info[:disabilities][1][:serviceRelevance]
        has_conditions = pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures]
        yyyy_date_format = claim_info[:disabilities][2][:approximateDate]

        expect(has_conditions).to eq('YES')
        expect(name).to eq('Traumatic Brain Injury')
        expect(relevance).to eq('ABCDEFG')
        expect(date).to eq('03/11/2018')
        expect(yyyy_date_format).to eq('2015')
        expect(event).to eq('EXPOSURE')
        expect(attribut_count).to eq(4)
        expect(secondary_name).to eq('Cancer - Musculoskeletal - Elbow')
        expect(secondary_event).to eq('EXPOSURE')
        expect(secondary_relevance).to eq('ABCDEFG')
      end

      it 'maps the secondary disability name to the primary disability correctly' do
        disability_name = form_attributes['disabilities'][0]['name']
        secondary_disability_name = form_attributes['disabilities'][0]['secondaryDisabilities'][0]['name']
        sd_label = "#{secondary_disability_name} secondary to: #{disability_name}"

        mapper.map_claim

        claim_info = pdf_data[:data][:attributes][:claimInformation]

        secondary_disability_label = claim_info[:disabilities][3][:disability]

        expect(secondary_disability_label).to eq(sd_label)
      end
    end

    context '526 section 5, claim info: disabilities, & has conditions attribute' do
      it 'maps the has_condition related to exposure method correctly' do
        mapper.map_claim

        has_conditions = pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures]

        expect(has_conditions).to eq('YES')
      end
    end

    context '526 section 5, treatment centers' do
      it 'maps the attributes correctly' do
        mapper.map_claim

        tx_center_data = pdf_data[:data][:attributes][:claimInformation][:treatments]

        start_date = tx_center_data[0][:dateOfTreatment]
        no_date = tx_center_data[0][:doNotHaveDate]
        treatment_details = tx_center_data[0][:treatmentDetails]

        expect(start_date).to eq({ month: '03', year: '2009' })
        expect(no_date).to eq(false)
        expect(treatment_details).to eq('Traumatic Brain Injury, Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders, Cancer - Musculoskeletal - Elbow - Center One, Decatur, GA') # rubocop:disable Layout/LineLength
      end

      it 'maps correctly when treatment center information is not provided' do
        form_attributes['treatments'][0]['center'] = nil

        mapper.map_claim
        details = 'Traumatic Brain Injury, Post Traumatic Stress Disorder (PTSD) Combat ' \
                  '- Mental Disorders, Cancer - Musculoskeletal - Elbow'
        treatment_info = pdf_data[:data][:attributes][:claimInformation][:treatments]
        treatment_details = treatment_info[0][:treatmentDetails]
        expect(treatment_details).to eq(details)
      end
    end

    context '526 section 5, treatment centers null data' do
      it 'maps the attributes correctly' do
        form_attributes['treatments'][0]['treatedDisabilityNames'] = nil
        form_attributes['treatments'][0]['center']['name'] = nil
        form_attributes['treatments'][0]['center']['city'] = nil
        form_attributes['treatments'][0]['center']['state'] = nil
        form_attributes['treatments'][0]['beginDate'] = nil
        mapper.map_claim

        tx_center_data = pdf_data[:data][:attributes][:claimInformation][:treatments]

        start_date = tx_center_data[0][:dateOfTreatment]
        no_date = tx_center_data[0][:doNotHaveDate]

        expect(start_date).to eq(nil)
        expect(no_date).to eq(true)
      end
    end

    context '526 section 6, service info' do
      it 'maps the attributes correctly' do
        mapper.map_claim

        serv_info = pdf_data[:data][:attributes][:serviceInformation]

        branch = serv_info[:branchOfService][:branch]
        component = serv_info[:serviceComponent]
        recent_start = serv_info[:mostRecentActiveService][:start]
        recent_end = serv_info[:mostRecentActiveService][:end]
        addtl_start = serv_info&.dig('additionalPeriodsOfService', '0', 'start')
        addtl_end = serv_info&.dig('additionalPeriodsOfService', '0', 'end')
        last_sep = serv_info[:placeOfLastOrAnticipatedSeparation]
        pow = serv_info[:confinedAsPrisonerOfWar]
        pow_start = serv_info[:prisonerOfWarConfinement][:confinementDates][0][:start]
        pow_end = serv_info[:prisonerOfWarConfinement][:confinementDates][0][:end]
        pow_start_two = serv_info[:prisonerOfWarConfinement][:confinementDates][1][:start]
        pow_end_two = serv_info[:prisonerOfWarConfinement][:confinementDates][1][:end]
        natl_guard = serv_info[:servedInReservesOrNationalGuard]
        natl_guard_comp = serv_info[:reservesNationalGuardService][:component]
        obl_begin = serv_info[:reservesNationalGuardService][:obligationTermsOfService][:start]
        obl_end = serv_info[:reservesNationalGuardService][:obligationTermsOfService][:end]
        unit_name = serv_info[:reservesNationalGuardService][:unitName]
        unit_address = serv_info[:reservesNationalGuardService][:unitAddress]
        unit_phone = serv_info[:reservesNationalGuardService][:unitPhoneNumber]
        act_duty_pay = serv_info[:reservesNationalGuardService][:receivingInactiveDutyTrainingPay]
        other_name = serv_info[:servedUnderAnotherName]
        fed_orders = serv_info[:activatedOnFederalOrders]
        alt_names = serv_info[:alternateNames]
        fed_act = serv_info[:federalActivation][:activationDate]
        fed_sep = serv_info[:federalActivation][:anticipatedSeparationDate]
        served_after_nine_eleven = serv_info[:servedInActiveCombatSince911]

        expect(branch).to eq('Public Health Service')
        expect(component).to eq('ACTIVE')
        expect(recent_start).to eq({ month: '11', day: '14', year: '2008' })
        expect(recent_end).to eq({ month: '10', day: '30', year: '2023' })
        expect(addtl_start).to eq(nil)
        expect(addtl_end).to eq(nil)
        expect(last_sep).to eq('Aberdeen Proving Ground')
        expect(pow).to eq('YES')
        expect(pow_start).to eq({ month: '06', day: '04', year: '2018' })
        expect(pow_end).to eq({ month: '07', day: '04', year: '2018' })
        expect(pow_start_two).to eq({ month: '06', year: '2020' })
        expect(pow_end_two).to eq({ month: '07', year: '2020' })
        expect(natl_guard).to eq('YES')
        expect(natl_guard_comp).to eq('NATIONAL_GUARD')
        expect(obl_begin).to eq({ month: '06', day: '04', year: '2019' })
        expect(obl_end).to eq({ month: '06', day: '04', year: '2020' })
        expect(unit_name).to eq('National Guard Unit Name')
        expect(unit_address).to eq('1243 pine court')
        expect(unit_phone).to eq('5555555555')
        expect(act_duty_pay).to eq('YES')
        expect(other_name).to eq('YES')
        expect(alt_names).to eq(['john jacob', 'johnny smith'])
        expect(fed_orders).to eq('YES')
        expect(fed_act).to eq({ month: '10', day: '01', year: '2023' })
        expect(fed_sep).to eq({ month: '10', day: '31', year: '2024' })
        expect(served_after_nine_eleven).to eq('NO')
      end

      it 'maps service info correctly with a nil phone number' do
        form_attributes['serviceInformation']['reservesNationalGuardService']['unitPhone']['areaCode'] = nil
        form_attributes['serviceInformation']['reservesNationalGuardService']['unitPhone']['phoneNumber'] = nil
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:unitPhoneNumber]
        expect(actual).to eq(nil)
      end

      it 'maps service info correctly when a phone number has a dash' do
        form_attributes['serviceInformation']['reservesNationalGuardService']['unitPhone']['areaCode'] = '303'
        arr = form_attributes['serviceInformation']['reservesNationalGuardService']['unitPhone']['phoneNumber'].chars
        arr.insert(3, '-')
        form_attributes['serviceInformation']['reservesNationalGuardService']['unitPhone']['phoneNumber'] = arr.join
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:serviceInformation][:reservesNationalGuardService][:unitPhoneNumber]
        expect(actual).to eq('3035555555')
      end

      it 'maps servedInReservesOrNationalGuard info correctly with a nil' do
        form_attributes['serviceInformation']['reservesNationalGuardService'] = nil
        mapper.map_claim

        actual = pdf_data[:data][:attributes][:serviceInformation][:servedInReservesOrNationalGuard]
        expect(actual).to eq(nil)
      end
    end

    context '526 section 7, service pay' do
      it 'maps the attributes correctly' do
        mapper.map_claim

        service_pay_data = pdf_data[:data][:attributes][:servicePay]
        favor_mil_retired_pay = service_pay_data[:favorMilitaryRetiredPay]
        receiving_mil_retired_pay = service_pay_data[:receivingMilitaryRetiredPay]
        branch_of_service = service_pay_data[:militaryRetiredPay][:branchOfService][:branch]

        expect(favor_mil_retired_pay).to eq(false)
        expect(receiving_mil_retired_pay).to eq('YES')
        expect(branch_of_service).to eq('Army')
      end
    end

    context '526 section 8, direct deposot' do
      it 'maps the attributes correctly' do
        mapper.map_claim

        dir_deposit = pdf_data[:data][:attributes][:directDepositInformation]

        account_type = dir_deposit[:accountType]
        account_number = dir_deposit[:accountNumber]
        routing_number = dir_deposit[:routingNumber]
        financial_institution_name = dir_deposit[:financialInstitutionName]
        no_account = dir_deposit[:noAccount]

        expect(account_type).to eq('CHECKING')
        expect(account_number).to eq('ABCDEF')
        expect(routing_number).to eq('123123123')
        expect(financial_institution_name).to eq('Chase')
        expect(no_account).to eq(false)
      end
    end

    context '526 section 9, date and signature' do
      it 'maps the attributes correctly' do
        auto_claim['data']['attributes']['claim_date'] = Timecop.freeze(Time.zone.parse('2023-11-01T08:00:00Z'))
        mapper.map_claim

        signature = pdf_data[:data][:attributes][:claimCertificationAndSignature][:signature]
        date = pdf_data[:data][:attributes][:claimCertificationAndSignature][:dateSigned]

        expect(date).to eq({ month: '11', day: '01', year: '2023' })
        expect(signature).to eq('abraham lincoln')
      end
    end

    context '526 Overflow Text' do
      it 'maps the attributes correctly' do
        mapper.map_claim

        notes_on_pdf = pdf_data[:data][:attributes][:overflowText]

        expect(notes_on_pdf).to eq('Some things that are important to know, and are not included in any other place.')
      end
    end

    context '526 #deep_compact' do
      it 'eliminates nil string values' do
        form_attributes['veteranIdentification']['mailingAddress']['addressLine2'] = nil
        form_attributes['veteranIdentification']['mailingAddress']['addressLine3'] = nil

        mapper.map_claim
        number_and_street = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:numberAndStreet]

        expect(number_and_street).to eq('1234 Couch Street')
      end

      it 'eliminates empty objects' do
        form_attributes['servicePay']['militaryRetiredPay'] = nil
        form_attributes['servicePay']['separationSeverancePay'] = nil
        form_attributes['servicePay']['preTaxAmountReceived'] = nil
        form_attributes['servicePay']['futureMilitaryRetiredPayExplanation'] = nil

        mapper.map_claim
        service_pay = pdf_data[:data][:attributes][:servicePay]
        expected = { favorTrainingPay: true, favorMilitaryRetiredPay: false, receivingMilitaryRetiredPay: 'YES',
                     futureMilitaryRetiredPay: 'YES', retiredStatus: 'PERMANENT_DISABILITY_RETIRED_LIST',
                     receivedSeparationOrSeverancePay: 'YES' }

        expect(service_pay).to eq(expected)
      end

      it 'eliminates empty strings and nil values' do
        form_attributes['servicePay']['favorTrainingPay'] = nil

        form_attributes['servicePay']['favorMilitaryRetiredPay'] = nil
        form_attributes['servicePay']['receivingMilitaryRetiredPay'] = nil
        form_attributes['servicePay']['militaryRetiredPay']['monthlyAmount'] = nil
        form_attributes['servicePay']['militaryRetiredPay']['branchOfService'] = ''
        form_attributes['servicePay']['futureMilitaryRetiredPay'] = nil
        form_attributes['servicePay']['receivedSeparationOrSeverancePay'] = ''
        form_attributes['servicePay']['retiredStatus'] = ''
        form_attributes['servicePay']['separationSeverancePay']['preTaxAmountReceived'] = nil
        form_attributes['servicePay']['separationSeverancePay']['datePaymentReceived'] = nil

        mapper.map_claim

        service_pay = pdf_data[:data][:attributes][:servicePay]
        expected = { receivingMilitaryRetiredPay: 'NO', futureMilitaryRetiredPay: 'NO',
                     futureMilitaryRetiredPayExplanation: 'ABCDEFGHIJKLMNOPQRSTUVW',
                     receivedSeparationOrSeverancePay: 'YES',
                     separationSeverancePay: { branchOfService: { branch: 'Naval Academy' } } }

        expect(service_pay).to eq(expected)
      end
    end
  end
end
