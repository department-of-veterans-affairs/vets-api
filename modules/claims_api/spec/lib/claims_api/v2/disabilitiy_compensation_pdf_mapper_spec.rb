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

    context '526 section 0, happy path' do
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

    context '526 section 1' do
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
  end
end
