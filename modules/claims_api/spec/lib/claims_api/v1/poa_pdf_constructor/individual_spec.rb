# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/poa_pdf_constructor/individual'
require_relative '../../../../support/pdf_matcher'

describe ClaimsApi::V1::PoaPdfConstructor::Individual do
  let(:temp) { create(:power_of_attorney, :with_full_headers) }
  let(:phone_country_codes_temp) { create(:power_of_attorney, :with_full_headers) }

  before do
    Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
    b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
    temp.form_data = {
      signatures: {
        veteran: b64_image,
        representative: b64_image
      },
      veteran: {
        address: {
          numberAndStreet: '2719 Hyperion Ave',
          city: 'Los Angeles',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        },
        phone: {
          areaCode: '555',
          phoneNumber: '5551337'
        }
      },
      serviceOrganization: {
        address: {
          numberAndStreet: '2719 Hyperion Ave',
          city: 'Los Angeles',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        }
      }
    }
    temp.save

    phone_country_codes_temp.form_data = {
      signatures: {
        veteran: b64_image,
        representative: b64_image
      },
      veteran: {
        address: {
          numberAndStreet: '2719 Hyperion Ave',
          city: 'Los Angeles',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        },
        phone: {
          countryCode: '1',
          areaCode: '555',
          phoneNumber: '5551337'
        }
      },
      serviceOrganization: {
        address: {
          numberAndStreet: '2719 Hyperion Ave',
          city: 'Los Angeles',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        }
      }
    }
    phone_country_codes_temp.save
  end

  after do
    Timecop.return
  end

  it 'construct pdf' do
    power_of_attorney = ClaimsApi::PowerOfAttorney.find(temp.id)
    data = power_of_attorney.form_data.deep_merge(
      {
        'veteran' => {
          'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
          'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
          'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
          'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
        }
      }
    )

    constructor = ClaimsApi::V1::PoaPdfConstructor::Individual.new
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '21-22A', 'signed_filled_final.pdf')
    generated_pdf = constructor.construct(data, id: power_of_attorney.id)
    expect(generated_pdf).to match_pdf_content_of(expected_pdf)
  end

  it 'constructs the pdf when phone country codes are present on form' do
    power_of_attorney = ClaimsApi::PowerOfAttorney.find(phone_country_codes_temp.id)
    data = power_of_attorney.form_data.deep_merge(
      {
        'veteran' => {
          'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
          'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
          'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
          'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
        }
      }
    )

    constructor = ClaimsApi::V1::PoaPdfConstructor::Individual.new
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '21-22A',
                                   'signed_filled_phone_country_codes.pdf')
    generated_pdf = constructor.construct(data, id: power_of_attorney.id)
    expect(generated_pdf).to match_pdf_content_of(expected_pdf)
  end
end
