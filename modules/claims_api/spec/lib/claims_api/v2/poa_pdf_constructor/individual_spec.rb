# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/poa_pdf_constructor/individual'
require_relative '../../../../support/pdf_matcher'

describe ClaimsApi::V2::PoaPdfConstructor::Individual do
  let(:temp) { create(:power_of_attorney, :with_full_headers) }
  let(:other_service_branch_temp) { create(:power_of_attorney, :with_full_headers) }
  let(:phone_country_codes_temp) { create(:power_of_attorney, :with_full_headers) }

  before do
    Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
    temp.form_data = {
      veteran: {
        serviceNumber: '987654321',
        serviceBranch: 'ARMY',
        address: {
          addressLine1: '2719 Hyperion Ave',
          city: 'Los Angeles',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        },
        phone: {
          areaCode: '555',
          phoneNumber: '5551337'
        },
        email: 'test@example.com'
      },
      claimant: {
        firstName: 'Lillian',
        middleInitial: 'A',
        lastName: 'Disney',
        email: 'lillian@disney.com',
        relationship: 'Spouse',
        address: {
          addressLine1: '2688 S Camino Real',
          city: 'Palm Springs',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        },
        phone: {
          areaCode: '555',
          phoneNumber: '5551337'
        }
      },
      representative: {
        poaCode: 'A1Q',
        registrationNumber: '1234',
        type: 'ATTORNEY',
        address: {
          addressLine1: '2719 Hyperion Ave',
          city: 'Los Angeles',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        }
      },
      recordConsent: true,
      consentAddressChange: true,
      consentLimits: %w[DRUG_ABUSE SICKLE_CELL],
      conditionsOfAppointment: ['Condition 1', 'Condition 2']
    }
    temp.save

    other_service_branch_temp.form_data = {
      veteran: {
        serviceNumber: '987654321',
        serviceBranch: 'OTHER',
        serviceBranchOther: 'Air National Guard',
        address: {
          addressLine1: '2719 Hyperion Ave',
          city: 'Los Angeles',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        },
        phone: {
          areaCode: '555',
          phoneNumber: '5551337'
        },
        email: 'test@example.com'
      },
      claimant: {
        firstName: 'Lillian',
        middleInitial: 'A',
        lastName: 'Disney',
        email: 'LILLian@disney.com',
        relationship: 'Spouse',
        address: {
          addressLine1: '2688 S Camino Real',
          city: 'Palm Springs',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        },
        phone: {
          areaCode: '555',
          phoneNumber: '5551337'
        }
      },
      representative: {
        poaCode: 'A1Q',
        type: 'ATTORNEY',
        registrationNumber: '1234',
        address: {
          addressLine1: '2719 Hyperion Ave',
          city: 'Los Angeles',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        }
      },
      recordConsent: true,
      consentAddressChange: true,
      consentLimits: %w[DRUG_ABUSE SICKLE_CELL],
      conditionsOfAppointment: ['Condition 1', 'Condition 2']
    }
    other_service_branch_temp.save

    phone_country_codes_temp.form_data = {
      veteran: {
        serviceNumber: '987654321',
        serviceBranch: 'ARMY',
        address: {
          addressLine1: '2719 Hyperion Ave',
          city: 'Los Angeles',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        },
        phone: {
          countryCode: '1',
          areaCode: '555',
          phoneNumber: '5551337'
        },
        email: 'test@example.com'
      },
      claimant: {
        firstName: 'Lillian',
        middleInitial: 'A',
        lastName: 'Disney',
        email: 'lillian@disney.com',
        relationship: 'Spouse',
        address: {
          addressLine1: '2688 S Camino Real',
          city: 'Palm Springs',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        },
        phone: {
          countryCode: '44',
          phoneNumber: '5551337'
        }
      },
      representative: {
        poaCode: 'A1Q',
        registrationNumber: '1234',
        type: 'ATTORNEY',
        address: {
          addressLine1: '2719 Hyperion Ave',
          city: 'Los Angeles',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        }
      },
      recordConsent: true,
      consentAddressChange: true,
      consentLimits: %w[DRUG_ABUSE SICKLE_CELL],
      conditionsOfAppointment: ['Condition 1', 'Condition 2']
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
        },
        'appointmentDate' => power_of_attorney.created_at,
        'text_signatures' => {
          'page2' => [
            {
              'signature' => 'Lillian Disney - signed via api.va.gov',
              'x' => 35,
              'y' => 306
            },
            {
              'signature' => 'Bob Law - signed via api.va.gov',
              'x' => 35,
              'y' => 200
            }
          ]
        },
        'representative' => {
          'firstName' => 'Bob',
          'lastName' => 'Law'
        }
      }
    )

    constructor = ClaimsApi::V2::PoaPdfConstructor::Individual.new
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '21-22A', 'v2',
                                   'signed_filled_final.pdf')
    generated_pdf = constructor.construct(data, id: power_of_attorney.id)
    expect(generated_pdf).to match_pdf_content_of(expected_pdf)
  end

  it "constructs the pdf when 'other service branch' is entered in" do
    power_of_attorney = ClaimsApi::PowerOfAttorney.find(other_service_branch_temp.id)
    data = power_of_attorney.form_data.deep_merge(
      {
        'veteran' => {
          'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
          'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
          'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
          'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
        },
        'appointmentDate' => power_of_attorney.created_at,
        'text_signatures' => {
          'page2' => [
            {
              'signature' => 'Lillian Disney - signed via api.va.gov',
              'x' => 35,
              'y' => 306
            },
            {
              'signature' => 'Bob Law - signed via api.va.gov',
              'x' => 35,
              'y' => 200
            }
          ]
        },
        'representative' => {
          'firstName' => 'Bob',
          'lastName' => 'Law'
        }
      }
    )

    constructor = ClaimsApi::V2::PoaPdfConstructor::Individual.new
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '21-22A', 'v2',
                                   'signed_filled_final_other_service_branch.pdf')
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
        },
        'appointmentDate' => power_of_attorney.created_at,
        'text_signatures' => {
          'page2' => [
            {
              'signature' => 'Lillian Disney - signed via api.va.gov',
              'x' => 35,
              'y' => 306
            },
            {
              'signature' => 'Bob Law - signed via api.va.gov',
              'x' => 35,
              'y' => 200
            }
          ]
        },
        'representative' => {
          'firstName' => 'Bob',
          'lastName' => 'Law'
        }
      }
    )

    constructor = ClaimsApi::V2::PoaPdfConstructor::Individual.new
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '21-22A', 'v2',
                                   'signed_filled_phone_country_codes.pdf')
    generated_pdf = constructor.construct(data, id: power_of_attorney.id)
    expect(generated_pdf).to match_pdf_content_of(expected_pdf)
  end
end
