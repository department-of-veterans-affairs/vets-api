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

    context '526 section 0, claim attributes' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the attributes correctly' do
        mapper.map_claim

        date_signed = pdf_data[:data][:attributes][:claimCertificationAndSignature][:dateSigned]
        claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

        expect(date_signed).to eq('2023-02-18')
        expect(claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
      end
    end

    context '526 section 1' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

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
        expect(zip).to eq('417261234')
        expect(state).to eq('OR')
      end

      it 'maps the other veteran info' do
        mapper.map_claim

        currently_va_employee = pdf_data[:data][:attributes][:identificationInformation][:currentlyVaEmployee]
        va_file_number = pdf_data[:data][:attributes][:identificationInformation][:vaFileNumber]
        email = pdf_data[:data][:attributes][:identificationInformation][:emailAddress][:email]
        agree_to_email =
          pdf_data[:data][:attributes][:identificationInformation][:emailAddress][:agreeToEmailRelatedToClaim]
        telephone = pdf_data[:data][:attributes][:identificationInformation][:veteranNumber][:telephone]
        international_telephone =
          pdf_data[:data][:attributes][:identificationInformation][:veteranNumber][:internationalTelephone]

        expect(currently_va_employee).to eq(false)
        expect(va_file_number).to eq('AB123CDEF')
        expect(email).to eq('valid@somedomain.com')
        expect(agree_to_email).to eq(true)
        expect(telephone).to eq('1234567890')
        expect(international_telephone).to eq('1234567890')
      end
    end

    context '526 section 2, change of address' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the dates' do
        mapper.map_claim

        beginning_date = pdf_data[:data][:attributes][:changeOfAddress][:dates][:beginningDate]
        ending_date = pdf_data[:data][:attributes][:changeOfAddress][:dates][:endingDate]
        type_of_addr_change = pdf_data[:data][:attributes][:changeOfAddress][:typeOfAddressChange]
        number_and_street = pdf_data[:data][:attributes][:changeOfAddress][:numberAndStreet]
        apartment_or_unit_number =
          pdf_data[:data][:attributes][:changeOfAddress][:apartmentOrUnitNumber]
        city = pdf_data[:data][:attributes][:changeOfAddress][:city]
        country = pdf_data[:data][:attributes][:changeOfAddress][:country]
        zip = pdf_data[:data][:attributes][:changeOfAddress][:zip]
        state = pdf_data[:data][:attributes][:changeOfAddress][:state]

        expect(beginning_date).to eq('2012-11-30')
        expect(ending_date).to eq('2013-10-11')
        expect(type_of_addr_change).to eq('TEMPORARY')
        expect(number_and_street).to eq('10 Peach St')
        expect(apartment_or_unit_number).to eq('Apt 1')
        expect(city).to eq('Atlanta')
        expect(country).to eq('US')
        expect(zip).to eq('422209897')
        expect(state).to eq('GA')
      end
    end

    context '526 section 3, homelessness' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

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
        expect(homeless_telephone).to eq('7028901212')
        expect(homeless_international_telephone).to eq('1234567890')
        expect(homeless_currently).to eq(true) # can't be both homess & at risk
        expect(homeless_situation_options).to eq('FLEEING_CURRENT_RESIDENCE')
        expect(homeless_currently_other_description).to eq('ABCDEFGHIJKLM')
      end
    end

    context '526 section 4, toxic exposure' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the attributes correctly' do
        mapper.map_claim

        toxic_exp_data = pdf_data[:data][:attributes][:exposureInformation][:toxicExposure]

        gulf_locations = toxic_exp_data[:gulfWarHazardService][:servedInGulfWarHazardLocations]
        gulf_start_date = toxic_exp_data[:gulfWarHazardService][:serviceDates][:startDate]
        gulf_end_date = toxic_exp_data[:gulfWarHazardService][:serviceDates][:endDate]

        herbicide_locations = toxic_exp_data[:herbicideHazardService][:servedInHerbicideHazardLocations]
        other_locations = toxic_exp_data[:herbicideHazardService][:otherLocationsServed]
        herb_start_date = toxic_exp_data[:herbicideHazardService][:serviceDates][:startDate]
        herb_end_date = toxic_exp_data[:herbicideHazardService][:serviceDates][:endDate]

        additional_exposures = toxic_exp_data[:additionalHazardExposures][:additionalExposures]
        specify_other_exp = toxic_exp_data[:additionalHazardExposures][:specifyOtherExposures]
        exp_start_date = toxic_exp_data[:additionalHazardExposures][:exposureDates][:startDate]
        exp_end_date = toxic_exp_data[:additionalHazardExposures][:exposureDates][:endDate]

        multi_exp_start_date = toxic_exp_data[:multipleExposures][:exposureDates][:startDate]
        multi_exp_end_date = toxic_exp_data[:multipleExposures][:exposureDates][:endDate]
        multi_exp_location = toxic_exp_data[:multipleExposures][:exposureLocation]
        multi_exp_hazard = toxic_exp_data[:multipleExposures][:hazardExposedTo]

        expect(gulf_locations).to eq(true)
        expect(gulf_start_date).to eq('2523-07-21')
        expect(gulf_end_date).to eq('1540-01-21')

        expect(herbicide_locations).to eq(true)
        expect(other_locations).to eq('ABCDEFGHIJKLM')
        expect(herb_start_date).to eq('0401-03-07')
        expect(herb_end_date).to eq('9754-10-31')

        expect(additional_exposures).to eq(%w[ASBESTOS SHAD])
        expect(specify_other_exp).to eq('ABCD')
        expect(exp_start_date).to eq('4520-07-30')
        expect(exp_end_date).to eq('3405-10-03')

        expect(multi_exp_start_date).to eq('8697-12-09')
        expect(multi_exp_end_date).to eq('5517-07-27')
        expect(multi_exp_location).to eq('ABCDEFGHIJKLMN')
        expect(multi_exp_hazard).to eq('ABCDEFGHIJKLMNO')
      end
    end

    context '526 section 5, claimInfo: diabilities' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the attributes correctly' do
        mapper.map_claim

        claim_info = pdf_data[:data][:attributes][:claimInformation]

        name = claim_info[:disabilities][0][:disability]
        relevance = claim_info[:disabilities][0][:serviceRelevance]
        date = claim_info[:disabilities][0][:approximateDate]
        is_related = claim_info[:disabilities][0][:isRelatedToToxicExposure]
        event = claim_info[:disabilities][0][:exposureOrEventOrInjury]
        attribut_count = claim_info[:disabilities][0].count
        secondary_name = claim_info[:disabilities][1][:disability]
        secondary_event = claim_info[:disabilities][1][:exposureOrEventOrInjury]
        secondary_relevance = claim_info[:disabilities][1][:serviceRelevance]
        has_conditions = pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures]

        expect(has_conditions).to eq(true)
        expect(name).to eq('PTSD (post traumatic stress disorder)')
        expect(relevance).to eq('ABCDEFG')
        expect(date).to eq('2018-03-02')
        expect(event).to eq('EXPOSURE')
        expect(is_related).to eq(true)
        expect(attribut_count).to eq(5)
        expect(secondary_name).to eq('Traumatic Brain Injury')
        expect(secondary_event).to eq('EXPOSURE')
        expect(secondary_relevance).to eq('ABCDEFG')
      end
    end

    context '526 section 5, claim info: disabilities, & has conditions attribute' do
      let(:form_attributes) { claim_without_exposure.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the has_condition related to exposure method correctly' do
        mapper.map_claim

        has_conditions = pdf_data[:data][:attributes][:exposureInformation][:hasConditionsRelatedToToxicExposures]

        expect(has_conditions).to eq(false)
      end
    end

    context '526 section 5, treatment centers' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the attributes correctly' do
        mapper.map_claim

        tx_center_data = pdf_data[:data][:attributes][:claimInformation][:treatments]

        start_date = tx_center_data[0][:dateOfTreatment]
        no_date = tx_center_data[0][:doNotHaveDate]
        treatment_details = tx_center_data[0][:treatmentDetails]

        expect(start_date).to eq('03-1985')
        expect(no_date).to eq(false)
        expect(treatment_details).to eq('PTSD (post traumatic stress disorder) - Center One, Decatur, GA')
      end
    end

    context '526 section 6, service info' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the attributes correctly' do
        mapper.map_claim

        serv_info = pdf_data[:data][:attributes][:serviceInformation]

        branch = serv_info[:branchOfService]
        component = serv_info[:serviceComponent]
        recent_start = serv_info[:mostRecentActiveService][:startDate]
        recent_end = serv_info[:mostRecentActiveService][:endDate]
        addtl_start = serv_info[:additionalPeriodsOfService][0][:startDate]
        addtl_end = serv_info[:additionalPeriodsOfService][0][:endDate]
        last_sep = serv_info[:placeOfLastOrAnticipatedSeparation]
        pow = serv_info[:confinedAsPrisonerOfWar]
        pow_start = serv_info[:prisonerOfWarConfinement][:confinementDates][0][:startDate]
        pow_end = serv_info[:prisonerOfWarConfinement][:confinementDates][0][:endDate]
        pow_start_two = serv_info[:prisonerOfWarConfinement][:confinementDates][1][:startDate]
        pow_end_two = serv_info[:prisonerOfWarConfinement][:confinementDates][1][:endDate]
        natl_guard = serv_info[:servedInReservesOrNationalGuard]
        natl_guard_comp = serv_info[:reservesNationalGuardService][:component]
        obl_start = serv_info[:reservesNationalGuardService][:obligationTermsOfService][:startDate]
        obl_end = serv_info[:reservesNationalGuardService][:obligationTermsOfService][:endDate]
        unit_name = serv_info[:reservesNationalGuardService][:unitName]
        unit_address = serv_info[:reservesNationalGuardService][:unitAddress]
        unit_phone = serv_info[:reservesNationalGuardService][:unitPhone]
        act_duty_pay = serv_info[:reservesNationalGuardService][:receivingInactiveDutyTrainingPay]
        other_name = serv_info[:servedUnderAnotherName]
        fed_orders = serv_info[:activatedOnFederalOrders]
        alt_names = serv_info[:alternateNames]
        fed_act = serv_info[:federalActivation][:activationDate]
        fed_sep = serv_info[:federalActivation][:anticipatedSeparationDate]
        served_after_nine_eleven = serv_info[:servedInActiveCombatSince911]

        expect(branch).to eq('Public Health Service')
        expect(component).to eq('Active')
        expect(recent_start).to eq('1980-11-14')
        expect(recent_end).to eq('1991-11-30')
        expect(addtl_start).to eq('1980-11-14')
        expect(addtl_end).to eq('1991-11-30')
        expect(last_sep).to eq('ABCDEFGHIJKLMN')
        expect(pow).to eq(true)
        expect(pow_start).to eq('2018-06-04')
        expect(pow_end).to eq('2018-07-04')
        expect(pow_start_two).to eq('2020-06-04')
        expect(pow_end_two).to eq('2020-07-04')
        expect(natl_guard).to eq(true)
        expect(natl_guard_comp).to eq('Active')
        expect(obl_start).to eq('2019-06-04')
        expect(obl_end).to eq('2020-06-04')
        expect(unit_name).to eq("''c'5'l'#l#2z")
        expect(unit_address).to eq('1243 pine court')
        expect(unit_phone[:areaCode]).to eq('555')
        expect(unit_phone[:phoneNumber]).to eq('5555555')
        expect(act_duty_pay).to eq(true)
        expect(other_name).to eq(true)
        expect(alt_names).to eq('john jacob, johnny smith')
        expect(fed_orders).to eq(true)
        expect(fed_act).to eq('3619-02-11')
        expect(fed_sep).to eq('6705-10-03')
        expect(served_after_nine_eleven).to eq(false)
      end
    end

    context '526 section 8, direct deposot' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data) }

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
        expect(financial_institution_name).to eq('Some Bank')
        expect(no_account).to eq(false)
      end
    end
  end
end
