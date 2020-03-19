# frozen_string_literal: true

require 'rails_helper'
require 'pp'

describe 'hlr_post JSON Schema', type: :request do
  let(:json_schema) do
    JSON.parse(
      File.read(
        Rails.root.join('modules', 'appeals_api', 'config', 'schemas', '200996.json')
      )
    )
  end

  let(:json) { input.as_json }
  let(:errors) { validator.validate(json).to_a }
  let(:validator) { JSONSchemer.schema(json_schema) }

  let(:informal_conference_rep_email_address) { 'josie@example.com' }
  let(:informal_conference_rep_phone_phone_type) { 'HOME' }
  let(:informal_conference_rep_phone_extension) { '2' }
  let(:informal_conference_rep_phone_phone_number) { '8001111' }
  let(:informal_conference_rep_phone_area_code) { '555' }
  let(:informal_conference_rep_phone_country_code) { '1' }
  let(:informal_conference_rep_phone_is_international) { false }
  let(:informal_conference_rep_phone) do
    {
      isInternational: informal_conference_rep_phone_is_international,
      countryCode: informal_conference_rep_phone_country_code,
      areaCode: informal_conference_rep_phone_area_code,
      phoneNumber: informal_conference_rep_phone_phone_number,
      extension: informal_conference_rep_phone_extension,
      phoneType: informal_conference_rep_phone_phone_type
    }
  end
  let(:informal_conference_rep_name) { 'Helen Holly' }
  let(:informal_conference_rep) do
    {
      name: informal_conference_rep_name,
      phone: informal_conference_rep_phone
    }
  end
  let(:informal_conference_times) do
    [
      '1230-1400 ET',
      '1400-1630 ET'
    ]
  end
  let(:claimant) do
    {
      participantId: claimant_participant_id,
      payeeCode: claimant_payee_code
    }
  end
  let(:claimant_participant_id) { "123" }
  let(:claimant_payee_code) { "10" }
  let(:veteran_email_address) { 'josie@example.com' }
  let(:veteran_phone_phone_type) { 'HOME' }
  let(:veteran_phone_extension) { '2' }
  let(:veteran_phone_phone_number) { '8001111' }
  let(:veteran_phone_area_code) { '555' }
  let(:veteran_phone_country_code) { '1' }
  let(:veteran_phone_is_international) { false }
  let(:veteran_phone) do
    {
      isInternational: veteran_phone_is_international,
      countryCode: veteran_phone_country_code,
      areaCode: veteran_phone_area_code,
      phoneNumber: veteran_phone_phone_number,
      extension: veteran_phone_extension,
      phoneType: veteran_phone_phone_type
    }
  end
  let(:veteran_address_address_pou) { 'RESIDENCE/CHOICE' }
  let(:veteran_address_country_name) { 'United States' }
  let(:veteran_address_zip_code) { '66002' }
  let(:veteran_address_state_code) { 'KS' }
  let(:veteran_address_city) { 'Atchison' }
  let(:veteran_address_address_line3) { 'c/o Amelia Earhart' }
  let(:veteran_address_address_line2) { 'Unit #724' }
  let(:veteran_address_address_line1) { '401 Kansas Avenue' }
  let(:veteran_address_address_type) { 'DOMESTIC' }
  let(:veteran_address) do
    {
      addressType: veteran_address_address_type,
      addressLine1: veteran_address_address_line1,
      addressLine2: veteran_address_address_line2,
      addressLine3: veteran_address_address_line3,
      city: veteran_address_city,
      stateCode: veteran_address_state_code,
      zipCode: veteran_address_zip_code,
      countryName: veteran_address_country_name,
      addressPou: veteran_address_address_pou
    }
  end
  let(:veteran) do
    {
      address: veteran_address,
      phone: veteran_phone,
      emailAddress: veteran_email_address
    }
  end
  let(:legacy_opt_in_approved) { true }
  let(:same_office) { true }
  let(:informal_conference) { true }
  let(:attributes) do
    {
      informalConference: informal_conference,
      sameOffice: same_office,
      legacyOptInApproved: legacy_opt_in_approved,
      benefitType: benefit_type,
      veteran: veteran,
      claimant: claimant,
      receiptDate: receipt_date,
      informalConferenceTimes: informal_conference_times,
      informalConferenceRep: informal_conference_rep
    }
  end
  let(:included) do
    [
      {
        type: 'ContestableIssue',
        attributes: {
          decisionIssueId: 1,
          ratingIssueId: '2',
          ratingDecisionIssueId: '3'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          decisionIssueId: 4,
          ratingIssueId: '5'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          ratingIssueId: '6',
          ratingDecisionIssueId: '7'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          decisionIssueId: 8,
          ratingDecisionIssueId: '9'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: { decisionIssueId: 10 }
      },
      {
        type: 'ContestableIssue',
        attributes: { ratingIssueId: '11' }
      },
      {
        type: 'ContestableIssue',
        attributes: { ratingDecisionIssueId: '12' }
      }
    ]
  end
  let(:data) { { type: 'HigherLevelReview', attributes: attributes } }
  let(:input) { { data: data, included: included } }
  let(:receipt_date) { '2020-02-02' }
  let(:benefit_type) { 'nca' }

  it('is valid JSON') { expect(json_schema).to be_a Hash }

  it('is valid JSON Schema') { expect(validator).to be_truthy }

  context 'every field used' do
    let(:input) do
      # ALL IN ONE PIECE TO SERVE AS AN EXAMPLE
      {
        data: {
          type: 'HigherLevelReview',
          attributes: {
            informalConference: true,
            sameOffice: true,
            legacyOptInApproved: true,
            benefitType: 'compensation',
            veteran: {
              address: {
                addressType: 'DOMESTIC',
                addressLine1: '401 Kansas Avenue',
                addressLine2: 'Unit #724',
                addressLine3: 'c/o Amelia Earhart',
                city: 'Atchison',
                stateCode: 'KS',
                zipCode: '66002',
                countryName: 'United States',
                addressPou: 'RESIDENCE/CHOICE'
              },
              phone: {
                isInternational: false,
                countryCode: '1',
                areaCode: '913',
                phoneNumber: '3671902',
                extension: '99',
                phoneType: 'HOME'
              },
              emailAddress: 'barbara@example.com'
            },
            claimant: {
              "participantId": '123',
              "payeeCode": '10'
            },
            receiptDate: '2020-02-02',
            informalConferenceTimes: [
              '1230-1400 ET',
              '1400-1630 ET'
            ],
            informalConferenceRep: {
              name: 'Joe Rep',
              phone: {
                isInternational: false,
                countryCode: '1',
                areaCode: '913',
                phoneNumber: '3677100',
                extension: '600',
                phoneType: 'MOBILE'
              }
            }
          }
        },
        included: [
          {
            type: 'ContestableIssue',
            attributes: {
              decisionIssueId: 100,
              ratingIssueId: '200',
              ratingDecisionIssueId: '300'
            }
          },
          {
            type: 'ContestableIssue',
            attributes: {
              decisionIssueId: 401,
              ratingIssueId: '501'
            }
          },
          {
            type: 'ContestableIssue',
            attributes: {
              ratingIssueId: '602',
              ratingDecisionIssueId: '702'
            }
          },
          {
            type: 'ContestableIssue',
            attributes: {
              decisionIssueId: 803,
              ratingDecisionIssueId: '904'
            }
          },
          {
            type: 'ContestableIssue',
            attributes: { decisionIssueId: 1005 }
          },
          {
            type: 'ContestableIssue',
            attributes: { ratingIssueId: '1106' }
          },
          {
            type: 'ContestableIssue',
            attributes: { ratingDecisionIssueId: '1207' }
          }
        ]
      }
    end

    it('has no errors') { expect(errors).to be_empty }
  end

  context 'only the booleans and benefitType are required' do
    let(:attributes) do
      {
        informalConference: informal_conference,
        sameOffice: same_office,
        legacyOptInApproved: legacy_opt_in_approved,
        benefitType: benefit_type
      }
    end
    let(:informal_conference) { false }

    it('has no errors') { expect(errors).to be_empty }

    context 'unless informalConference is true' do
      let(:informal_conference) { true }

      it('has errors') { expect(errors).not_to be_empty }

      context 'with informalConferenceTimes' do
        let(:attributes) do
          {
            informalConference: true,
            sameOffice: same_office,
            legacyOptInApproved: legacy_opt_in_approved,
            benefitType: benefit_type,
            informalConferenceTimes: informal_conference_times
          }
        end

        it('has no errors') { expect(errors).to be_empty }
      end
    end
  end

  context 'veteran field is nil' do
    let(:veteran) { nil }
    it('has errors') { expect(errors).not_to be_empty }
  end

  context 'veteran field is an empty object' do
    let(:veteran) { {} }
    it('has errors') { expect(errors).not_to be_empty }
  end
end
