# frozen_string_literal: true

require 'rails_helper'
require 'pp'

# it('has no errors') do
#   pp errors.map { |error| error['data_pointer'] } unless errors.empty?
#   puts
#   pp errors unless errors.empty?
#   expect(errors).to be_empty
# end

describe 'VA Form 20-0996 JSON Schema', type: :request do
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
  let(:data) { { type: 'HigherLevelReview', attributes: data_attributes } }
  let(:input) { { data: data, included: included } }

  it('JSON is valid') { expect(json_schema).to be_a Hash }

  it('JSON Schema is valid') { expect(validator).to be_truthy }

  context 'all fields used' do
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

  context 'data:' do
    let(:data_attributes) { data_attributes_template }
    let(:data_attributes_template) do
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
    let(:informal_conference_rep_phone) { informal_conference_rep_phone_template }
    let(:informal_conference_rep_phone_template) do
      {
        isInternational: informal_conference_rep_phone_is_international,
        countryCode: informal_conference_rep_phone_country_code,
        areaCode: informal_conference_rep_phone_area_code,
        phoneNumber: informal_conference_rep_phone_phone_number,
        extension: informal_conference_rep_phone_extension,
        phoneType: informal_conference_rep_phone_phone_type
      }
    end
    let(:informal_conference_rep) { informal_conference_rep_template }
    let(:informal_conference_rep_template) do
      {
        name: informal_conference_rep_name,
        phone: informal_conference_rep_phone
      }
    end
    let(:claimant) { claimant_template }
    let(:claimant_template) do
      {
        participantId: claimant_participant_id,
        payeeCode: claimant_payee_code
      }
    end
    let(:veteran) { veteran_template }
    let(:veteran_template) do
      {
        address: veteran_address,
        phone: veteran_phone,
        emailAddress: veteran_email_address
      }
    end
    let(:veteran_address) { veteran_address_template }
    let(:veteran_address_template) do
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
    let(:veteran_phone) { veteran_phone_template }
    let(:veteran_phone_template) do
      {
        isInternational: veteran_phone_is_international,
        countryCode: veteran_phone_country_code,
        areaCode: veteran_phone_area_code,
        phoneNumber: veteran_phone_phone_number,
        extension: veteran_phone_extension,
        phoneType: veteran_phone_phone_type
      }
    end

    let(:informal_conference_rep_email_address) { 'josie@example.com' }
    let(:informal_conference_rep_phone_phone_type) { 'HOME' }
    let(:informal_conference_rep_phone_extension) { '2' }
    let(:informal_conference_rep_phone_phone_number) { '8001111' }
    let(:informal_conference_rep_phone_area_code) { '555' }
    let(:informal_conference_rep_phone_country_code) { '1' }
    let(:informal_conference_rep_phone_is_international) { false }
    let(:informal_conference_rep_name) { 'Helen Holly' }
    let(:informal_conference_times) { ['1230-1400 ET', '1400-1630 ET'] }
    let(:claimant_participant_id) { '123' }
    let(:claimant_payee_code) { '10' }
    let(:veteran_email_address) { 'josie@example.com' }
    let(:veteran_phone_phone_type) { 'HOME' }
    let(:veteran_phone_extension) { '2' }
    let(:veteran_phone_phone_number) { '8001111' }
    let(:veteran_phone_area_code) { '555' }
    let(:veteran_phone_country_code) { '1' }
    let(:veteran_phone_is_international) { false }
    let(:veteran_address_address_pou) { 'RESIDENCE/CHOICE' }
    let(:veteran_address_country_name) { 'United States' }
    let(:veteran_address_zip_code) { '66002' }
    let(:veteran_address_state_code) { 'KS' }
    let(:veteran_address_city) { 'Atchison' }
    let(:veteran_address_address_line3) { 'c/o Amelia Earhart' }
    let(:veteran_address_address_line2) { 'Unit #724' }
    let(:veteran_address_address_line1) { '401 Kansas Avenue' }
    let(:veteran_address_address_type) { 'DOMESTIC' }
    let(:legacy_opt_in_approved) { true }
    let(:same_office) { true }
    let(:informal_conference) { true }
    let(:receipt_date) { '2020-02-02' }
    let(:benefit_type) { 'nca' }

    context 'attributes:' do
      it('has no errors') { expect(errors).to be_empty }

      context 'informalConference:' do
        context 'true' do
          let(:informal_conference) { true }

          context '(without fields: informalConferenceTimes, informalConferenceRep)' do
            let(:data_attributes) do
              data_attributes_template.except(
                :informalConferenceTimes,
                :informalConferenceRep
              )
            end

            it('HAS ERRORS') { expect(errors).not_to be_empty }
          end

          context '(without field informalConferenceRep)' do
            let(:data_attributes) { data_attributes_template.except(:informalConferenceRep) }

            it('has no errors (must have at least ...Times if requesting conference)') do
              expect(errors).to be_empty
            end
          end
        end

        context 'false' do
          let(:informal_conference) { false }

          it('HAS ERRORS') { expect(errors).not_to be_empty }

          context '(without field informalConferenceRep)' do
            let(:data_attributes) { data_attributes_template.except(:informalConferenceRep) }

            it('HAS ERRORS') { expect(errors).not_to be_empty }
          end

          context '(without field informalConferenceTimes)' do
            let(:data_attributes) { data_attributes_template.except(:informalConferenceTimes) }

            it('HAS ERRORS') { expect(errors).not_to be_empty }
          end

          context '(without fields: informalConferenceTimes, informalConferenceRep)' do
            let(:data_attributes) do
              data_attributes_template.except(
                :informalConferenceTimes,
                :informalConferenceRep
              )
            end

            it('has no errors (cannot use ...Times or ...Rep field if not requesting an conference)') do
              expect(errors).to be_empty
            end
          end
        end
      end

      context '(with only fields: informalConference, sameOffice, legacyOptInApproved, benefitType)' do
        let(:attributes) do
          {
            informalConference: informal_conference,
            sameOffice: same_office,
            legacyOptInApproved: legacy_opt_in_approved,
            benefitType: benefit_type
          }
        end

        it('has no errors (benefitType and boolean fields are the only required fields)') do
          expect(errors).to be_empty
        end
      end

      context 'veteran:' do
        it('has no errors') { expect(errors).to be_empty }

        context 'field absent' do
          let(:data_attributes) { data_attributes_template.except(:veteran) }

          it('has no errors (unless updating phone/address/email, you don\'t need to use the veteran field)') do
            expect(errors).to be_empty
          end
        end

        context 'nil' do
          let(:veteran) { nil }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end

        context '{}' do
          let(:veteran) { {} }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end

        context '{...}' do
          context 'address:' do
            it('has no errors') { expect(errors).to be_empty }

            context '(without fields: addressLine2, addressLine3)' do
              let(:veteran_address) do
                {
                  addressType: veteran_address_address_type,
                  addressLine1: veteran_address_address_line1,
                  city: veteran_address_city,
                  stateCode: veteran_address_state_code,
                  zipCode: veteran_address_zip_code,
                  countryName: veteran_address_country_name,
                  addressPou: veteran_address_address_pou
                }
              end

              it('has no errors (addressLine2 and addressLine3 are optional') { expect(errors).to be_empty }
            end

            context 'addressType: OVERSEAS MILITARY' do
              let(:veteran_address_address_type) { 'OVERSEAS MILITARY' }

              it('has no errors (OVERSEAS MILITARY has the same conditions/requirement as DOMESTIC)') do
                expect(errors).to be_empty
              end
            end

            context 'addressType: INTERNATIONAL' do
              let(:veteran_address_address_type) { 'INTERNATIONAL' }

              it('HAS ERRORS') { expect(errors).not_to be_empty }

              context '(without fields: stateCode, zipCode)' do
                let(:veteran_address) do
                  {
                    addressType: veteran_address_address_type,
                    addressLine1: veteran_address_address_line1,
                    city: veteran_address_city,
                    countryName: veteran_address_country_name,
                    addressPou: veteran_address_address_pou
                  }
                end

                it('HAS ERRORS') { expect(errors).not_to be_empty }

                context '(with field: internationalPostalCode)' do
                  let(:veteran_address) do
                    {
                      addressType: veteran_address_address_type,
                      addressLine1: veteran_address_address_line1,
                      city: veteran_address_city,
                      internationalPostalCode: 'any string 0123',
                      countryName: veteran_address_country_name,
                      addressPou: veteran_address_address_pou
                    }
                  end

                  it(
                    'has no errors (must have field internationalPostalCode.' \
                    'cannot have fields stateCode or zipCode)'
                  ) do
                    expect(errors).to be_empty
                  end
                end
              end
            end

            context 'stateCode:' do
              context '"KS"' do
                let(:veteran_address_state_code) { 'KS' }

                it('has no errors') { expect(errors).to be_empty }
              end

              context '""' do
                let(:veteran_address_state_code) { '' }

                it('HAS ERRORS') { expect(errors).not_to be_empty }
              end

              context '(tabs)' do
                context '(2x)' do
                  let(:veteran_address_state_code) { '		' }

                  it('HAS ERRORS') { expect(errors).not_to be_empty }
                end

                context '(1x)' do
                  let(:veteran_address_state_code) { '	' }

                  it('HAS ERRORS') { expect(errors).not_to be_empty }
                end
              end

              context '\u3000' do
                context '(2x)' do
                  let(:veteran_address_state_code) { "\u3000\u3000" }

                  it('HAS ERRORS') { expect(errors).not_to be_empty }
                end

                context '(1x)' do
                  let(:veteran_address_state_code) { "\u3000" }

                  it('HAS ERRORS') { expect(errors).not_to be_empty }
                end
              end
            end
          end

          context 'email:' do
            context 'judy@example.com' do
              let(:veteran_email_address) { 'judy@example.com' }

              it('has no errors') { expect(errors).to be_empty }
            end

            context 'empty string' do
              let(:veteran_email_address) { '' }

              it('HAS ERRORS') { expect(errors).not_to be_empty }
            end

            context 'nil' do
              let(:veteran_email_address) { '' }

              it('HAS ERRORS') { expect(errors).not_to be_empty }
            end

            context 'no @' do
              let(:veteran_email_address) { 'cat' }

              it('HAS ERRORS') { expect(errors).not_to be_empty }
            end
          end

          context 'phone:' do
            context 'extension:' do
              context 'field absent' do
                let(:veteran_phone) do
                  {
                    isInternational: veteran_phone_is_international,
                    countryCode: veteran_phone_country_code,
                    areaCode: veteran_phone_area_code,
                    phoneNumber: veteran_phone_phone_number,
                    phoneType: veteran_phone_phone_type
                  }
                end

                it('has no errors (extension is optional)') { expect(errors).to be_empty }
              end
            end
          end
        end
      end

      context 'claimant:' do
        it('has no errors (participantId and payeeCode are required)') { expect(errors).to be_empty }

        context '(without field: participantId)' do
          let(:claimant) { claimant_template.except(:participantId) }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end

        context '(without field: payeeCode)' do
          let(:claimant) { claimant_template.except(:payeeCode) }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end
      end
    end
  end
end
