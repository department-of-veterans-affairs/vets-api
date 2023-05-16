# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_pdf_mapper'

describe ClaimsApi::V2::DisabilitiyCompensationPdfMapper do
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

    context '526 section 0, claim attributes' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilitiyCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the claim date' do
        mapper.map_claim

        date_signed = pdf_data[:data][:attributes][:claimCertificationAndSignature][:dateSigned]
        claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

        expect(date_signed).to eq('2023-02-18')
        expect(claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
      end
    end

    context '526 section 1, veteran identification' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilitiyCompensationPdfMapper.new(form_attributes, pdf_data) }

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
        expect(country).to eq('USA')
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
      let(:mapper) { ClaimsApi::V2::DisabilitiyCompensationPdfMapper.new(form_attributes, pdf_data) }

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

        expect(beginning_date).to eq('2012-11-31')
        expect(ending_date).to eq('2013-10-11')
        expect(type_of_addr_change).to eq('TEMPORARY')
        expect(number_and_street).to eq('10 Peach St')
        expect(apartment_or_unit_number).to eq('Apt 1')
        expect(city).to eq('Atlanta')
        expect(country).to eq('USA')
        expect(zip).to eq('422209897')
        expect(state).to eq('GA')
      end
    end

    context '526 section 3, homelessness' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilitiyCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the homeless_point_of_contact' do
        mapper.map_claim

        homeless_point_of_contact = pdf_data[:data][:attributes][:homelessInformation][:pointOfContact]
        homeless_telephone = pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber][:telephone]
        homeless_international_telephone =
          pdf_data[:data][:attributes][:homelessInformation][:pointOfContactNumber][:internationalTelephone]
        homeless_currently = pdf_data[:data][:attributes][:homelessInformation][:areYouCurrentlyHomeless]
        homeless_risk_other_description =
          pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless][:otherDescription]
        homeless_situation_options =
          pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless][:homelessSituationOptions]
        homeless_at_risk_living_situation_options =
          pdf_data[:data][:attributes][:homelessInformation][:riskOfBecomingHomeless][:livingSituationOptions]
        homeless_currently_other_description =
          pdf_data[:data][:attributes][:homelessInformation][:currentlyHomeless][:otherDescription]
        homeless_at_risk_at_becoming =
          pdf_data[:data][:attributes][:homelessInformation][:areYouAtRiskOfBecomingHomeless]

        expect(homeless_point_of_contact).to eq('john stewart')
        expect(homeless_telephone).to eq('7028901212')
        expect(homeless_international_telephone).to eq('1234567890')
        expect(homeless_currently).to eq(nil) # can't be both homess & at risk
        expect(homeless_situation_options).to eq('FLEEING_CURRENT_RESIDENCE')
        expect(homeless_currently_other_description).to eq('ABCDEFGHIJKLM')
        expect(homeless_at_risk_at_becoming).to eq(true)
        expect(homeless_at_risk_living_situation_options).to eq('other')
        expect(homeless_risk_other_description).to eq('ABCDEFGHIJKLMNOP')
      end
    end
  end
end
