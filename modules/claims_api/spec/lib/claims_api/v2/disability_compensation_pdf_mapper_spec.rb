# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_pdf_mapper'

describe ClaimsApi::V2::DisabilityCompensationPdfMapper do
  describe '526 claim maps to the pdf generator' do
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

    let(:claim_without_exposure) do
      JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'config',
          'schemas',
          'v2',
          'request_bodies',
          'disability_compensation',
          'example.json'
        ).read
      )
    end
    let(:target_veteran) do
      OpenStruct.new(
        icn: '1013062086V794840',
        first_name: 'abraham',
        last_name: 'lincoln',
        loa: { current: 3, highest: 3 },
        ssn: '796111863',
        edipi: '8040545646',
        participant_id: '600061742',
        mpi: OpenStruct.new(
          icn: '1013062086V794840',
          profile: OpenStruct.new(ssn: '796111863')
        )
      )
    end

    context '526 section 0, claim attributes' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

      it 'maps the attributes correctly' do
        mapper.map_claim

        claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

        expect(claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
      end
    end

    context '526 section 1' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

      it 'maps the mailing address' do
        mapper.map_claim

        number_and_street = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:numberAndStreet]
        apartment_or_unit_number =
          pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:apartmentOrUnitNumber]
        city = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:city]
        country = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:country]
        zip = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:zip]
        state = pdf_data[:data][:attributes][:identificationInformation][:mailingAddress][:state]

        expect(number_and_street).to eq('1234 Couch Street')
        expect(apartment_or_unit_number).to eq('22')
        expect(city).to eq('Portland')
        expect(country).to eq('US')
        expect(zip).to eq('41726-1234')
        expect(state).to eq('OR')
      end

      it 'maps the other veteran info' do
        mapper.map_claim

        current_va_employee = pdf_data[:data][:attributes][:identificationInformation][:currentVaEmployee]
        va_file_number = pdf_data[:data][:attributes][:identificationInformation][:vaFileNumber]
        email = pdf_data[:data][:attributes][:identificationInformation][:emailAddress][:email]
        agree_to_email =
          pdf_data[:data][:attributes][:identificationInformation][:emailAddress][:agreeToEmailRelatedToClaim]
        telephone = pdf_data[:data][:attributes][:identificationInformation][:phoneNumber][:telephone]
        international_telephone =
          pdf_data[:data][:attributes][:identificationInformation][:phoneNumber][:internationalTelephone]

        expect(current_va_employee).to eq(false)
        expect(va_file_number).to eq('AB123CDEF')
        expect(email).to eq('valid@somedomain.com')
        expect(agree_to_email).to eq(true)
        expect(telephone).to eq('5555555555')
        expect(international_telephone).to eq('5555555555')
      end
    end

    context '526 section 2, change of address' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

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

        expect(begin_date).to eq({ month: 11, day: 30, year: 2012 })
        expect(end_date).to eq({ month: 10, day: 11, year: 2013 })
        expect(type_of_addr_change).to eq('TEMPORARY')
        expect(number_and_street).to eq('10 Peach St')
        expect(apartment_or_unit_number).to eq('22')
        expect(city).to eq('Atlanta')
        expect(country).to eq('US')
        expect(zip).to eq('42220-9897')
        expect(state).to eq('GA')
      end
    end

    context '526 section 3, homelessness' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

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
        expect(homeless_telephone).to eq('5555555555')
        expect(homeless_international_telephone).to eq('5555555555')
        expect(homeless_currently).to eq('YES') # can't be both homess & at risk
        expect(homeless_situation_options).to eq('FLEEING_CURRENT_RESIDENCE')
        expect(homeless_currently_other_description).to eq('ABCDEFGHIJKLM')
      end
    end

    context '526 section 4, toxic exposure' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

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
        expect(gulf_begin_date).to eq({ month: 7, year: 2018 })
        expect(gulf_end_date).to eq({ month: 8, year: 2018 })

        expect(herbicide_locations).to eq('YES')
        expect(other_locations).to eq('ABCDEFGHIJKLM')
        expect(herb_begin_date).to eq({ month: 7, year: 2018 })
        expect(herb_end_date).to eq({ month: 8, year: 2018 })

        expect(additional_exposures).to eq(%w[ASBESTOS SHIPBOARD_HAZARD_AND_DEFENSE])
        expect(specify_other_exp).to eq('Other exposure details')
        expect(exp_begin_date).to eq({ month: 7, year: 2018 })
        expect(exp_end_date).to eq({ month: 8, year: 2018 })

        expect(multi_exp_begin_date).to eq({ month: 12, year: 2012 })
        expect(multi_exp_end_date).to eq({ month: 7, year: 2013 })
        expect(multi_exp_location).to eq('Guam')
        expect(multi_exp_hazard).to eq('RADIATION')
      end
    end

    context '526 section 5, claimInfo: diabilities' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

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

        expect(has_conditions).to eq('YES')
        expect(name).to eq('Traumatic Brain Injury')
        expect(relevance).to eq('ABCDEFG')
        expect(date).to eq('March 2018')
        expect(event).to eq('EXPOSURE')
        expect(attribut_count).to eq(4)
        expect(secondary_name).to eq('Cancer - Musculoskeletal - Elbow')
        expect(secondary_event).to eq('EXPOSURE')
        expect(secondary_relevance).to eq('ABCDEFG')
      end
    end

    context '526 section 5, claim info: disabilities, & has conditions attribute' do
      let(:form_attributes) { claim_without_exposure.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

      it 'maps the has_condition related to exposure method correctly' do
        mapper.map_claim

        has_conditions = pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures]

        expect(has_conditions).to eq('YES')
      end
    end

    context '526 section 5, treatment centers' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

      it 'maps the attributes correctly' do
        mapper.map_claim

        tx_center_data = pdf_data[:data][:attributes][:claimInformation][:treatments]

        start_date = tx_center_data[0][:dateOfTreatment]
        no_date = tx_center_data[0][:doNotHaveDate]
        treatment_details = tx_center_data[0][:treatmentDetails]

        expect(start_date).to eq({ month: 3, year: 1985 })
        expect(no_date).to eq(false)
        expect(treatment_details).to eq('Traumatic Brain Injury, Post Traumatic Stress Disorder (PTSD) Combat - Mental Disorders, Cancer - Musculoskeletal - Elbow - Center One, Decatur, GA') # rubocop:disable Layout/LineLength
      end
    end

    context '526 section 6, service info' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

      it 'maps the attributes correctly' do
        mapper.map_claim

        serv_info = pdf_data[:data][:attributes][:serviceInformation]

        branch = serv_info[:branchOfService][:branch]
        component = serv_info[:serviceComponent]
        recent_start = serv_info[:mostRecentActiveService][:start]
        recent_end = serv_info[:mostRecentActiveService][:end]
        addtl_start = serv_info[:additionalPeriodsOfService][0][:start]
        addtl_end = serv_info[:additionalPeriodsOfService][0][:end]
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
        expect(recent_start).to eq({ month: 11, day: 14, year: 1980 })
        expect(recent_end).to eq({ month: 11, day: 30, year: 1991 })
        expect(addtl_start).to eq({ month: 11, day: 14, year: 1980 })
        expect(addtl_end).to eq({ month: 11, day: 30, year: 1991 })
        expect(last_sep).to eq('ABCDEFGHIJKLMN')
        expect(pow).to eq('YES')
        expect(pow_start).to eq({ month: 6, day: 4, year: 2018 })
        expect(pow_end).to eq({ month: 6, day: 4, year: 2018 })
        expect(pow_start_two).to eq({ month: 6, year: 2020 })
        expect(pow_end_two).to eq({ month: 6, year: 2020 })
        expect(natl_guard).to eq('YES')
        expect(natl_guard_comp).to eq('NATIONAL_GUARD')
        expect(obl_begin).to eq({ month: 6, day: 4, year: 2019 })
        expect(obl_end).to eq({ month: 6, day: 4, year: 2020 })
        expect(unit_name).to eq('National Guard Unit Name')
        expect(unit_address).to eq('1243 pine court')
        expect(unit_phone).to eq('5555555555')
        expect(act_duty_pay).to eq('YES')
        expect(other_name).to eq('YES')
        expect(alt_names).to eq('john jacob, johnny smith')
        expect(fed_orders).to eq('YES')
        expect(fed_act).to eq({ month: 2, day: 11, year: 3619 })
        expect(fed_sep).to eq({ month: 10, day: 3, year: 6705 })
        expect(served_after_nine_eleven).to eq('NO')
      end
    end

    context '526 section 7, service pay' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

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
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

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
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data, target_veteran) }

      it 'maps the attributes correctly' do
        mapper.map_claim
        @target_veteran = target_veteran

        signature = pdf_data[:data][:attributes][:claimCertificationAndSignature][:signature]
        date = pdf_data[:data][:attributes][:claimCertificationAndSignature][:dateSigned]

        expect(date).to eq({ month: 2, day: 18, year: 2023 })
        expect(signature).to eq('abraham lincoln')
      end
    end
  end
end
