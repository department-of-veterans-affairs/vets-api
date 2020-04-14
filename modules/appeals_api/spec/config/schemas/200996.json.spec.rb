# frozen_string_literal: true

require 'rails_helper'
require 'pp'

describe 'VA Form 20-0996 JSON Schema', type: :request do
  let(:json_schema) do
    JSON.parse(
      File.read(
        Rails.root.join('modules', 'appeals_api', 'config', 'schemas', '200996.json')
      )
    )
  end

  let(:errors) { validator.validate(json).to_a }

  let(:validator) { JSONSchemer.schema(json_schema) }

  let(:json) { input.as_json }
  let(:input) { { data: data, included: included } }
  let(:data) { { type: 'HigherLevelReview', attributes: data_attributes } }
  let(:included) { included_template }
  let(:included_template) do
    [
      {
        type: 'ContestableIssue',
        attributes: {
          issue: 'tinnitus',
          decisionDate: '1900-01-01',
          decisionIssueId: 1,
          ratingIssueId: '2',
          ratingDecisionIssueId: '3'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          issue: 'left knee',
          decisionDate: '1900-01-02',
          decisionIssueId: 4,
          ratingIssueId: '5'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          issue: 'right knee',
          decisionDate: '1900-01-03',
          ratingIssueId: '6',
          ratingDecisionIssueId: '7'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          issue: 'PTSD',
          decisionDate: '1900-01-04',
          decisionIssueId: 8,
          ratingDecisionIssueId: '9'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          issue: 'Traumatic Brain Injury',
          decisionDate: '1900-01-05',
          decisionIssueId: 10
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          issue: 'right shoulder',
          decisionDate: '1900-01-06',
          ratingIssueId: '11'
        }
      },
      {
        type: 'ContestableIssue',
        attributes: {
          issue: 'left shoulder',
          decisionDate: '1900-01-07',
          ratingDecisionIssueId: '12'
        }
      }
    ]
  end
  let(:data_attributes) { data_attributes_template }
  let(:data_attributes_template) do
    {
      informalConference: informal_conference,
      sameOffice: same_office,
      benefitType: benefit_type,
      veteran: veteran,
      receiptDate: receipt_date,
      informalConferenceTimes: informal_conference_times,
      informalConferenceRep: informal_conference_rep
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
  let(:informal_conference_rep) { informal_conference_rep_template }
  let(:informal_conference_rep_template) do
    {
      name: informal_conference_rep_name,
      phone: informal_conference_rep_phone
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
  let(:receipt_date) { '2020-02-02' }
  let(:informal_conference) { true }
  let(:same_office) { true }
  let(:veteran_address_address_type) { 'DOMESTIC' }
  let(:veteran_address_address_line1) { '401 Kansas Avenue' }
  let(:veteran_address_address_line2) { 'Unit #724' }
  let(:veteran_address_address_line3) { 'c/o Amelia Earhart' }
  let(:veteran_address_city) { 'Atchison' }
  let(:veteran_address_state_code) { 'KS' }
  let(:veteran_address_zip_code) { '66002' }
  let(:veteran_address_country_name) { 'United States' }
  let(:veteran_address_address_pou) { 'RESIDENCE/CHOICE' }
  let(:veteran_phone_is_international) { false }
  let(:veteran_phone_country_code) { '1' }
  let(:veteran_phone_area_code) { '555' }
  let(:veteran_phone_phone_number) { '8001111' }
  let(:veteran_phone_extension) { '2' }
  let(:veteran_phone_phone_type) { 'HOME' }
  let(:veteran_email_address) { 'josie@example.com' }
  let(:informal_conference_times) { ['1230-1400 ET', '1400-1630 ET'] }
  let(:informal_conference_rep_name) { 'Helen Holly' }
  let(:informal_conference_rep_phone_is_international) { false }
  let(:informal_conference_rep_phone_country_code) { '1' }
  let(:informal_conference_rep_phone_area_code) { '555' }
  let(:informal_conference_rep_phone_phone_number) { '8001111' }
  let(:informal_conference_rep_phone_extension) { '2' }
  let(:informal_conference_rep_phone_phone_type) { 'HOME' }
  let(:informal_conference_rep_email_address) { 'josie@example.com' }
  let(:benefit_type) { 'nca' }

  it('JSON is valid') { expect(json_schema).to be_a Hash }

  it('JSON Schema is valid') { expect(validator).to be_truthy }

  context 'template is valid' do
    it('has no errors') do
      puts
      puts '######  EXAMPLE JSON  ######'
      puts
      pp input
      puts
      puts '############################'
      puts
      expect(errors).to be_empty
    end
  end

  context 'data:' do
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

      context '(with only fields: informalConference, sameOffice, benefitType)' do
        let(:attributes) do
          {
            informalConference: informal_conference,
            sameOffice: same_office,
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

          it('HAS ERRORS') { expect(errors).not_to be_empty }
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

      context 'informalConferenceTimes:' do
        let(:informal_conference) { true }
        let(:all_time_ranges) do
          [
            '800-1000 ET',
            '1000-1230 ET',
            '1230-1400 ET',
            '1400-1630 ET'
          ]
        end

        it('has no errors') { expect(errors).to be_empty }

        context 'all 4 ranges' do
          let(:informal_conference_times) { all_time_ranges }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end

        context '3 ranges' do
          let(:informal_conference_times) { all_time_ranges[1..3] }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end

        context '2 ranges' do
          let(:informal_conference_times) { [all_time_ranges[0], all_time_ranges[3]] }

          it('has no errors') { expect(errors).to be_empty }
        end

        context '1 range' do
          let(:informal_conference_times) { [all_time_ranges[2]] }

          it('has no errors') { expect(errors).to be_empty }
        end

        context '[]' do
          let(:informal_conference_times) { [] }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end

        context 'nil' do
          let(:informal_conference_times) { nil }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end

        context 'invalid range' do
          let(:informal_conference_times) { ['afternoon is fine'] }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end

        context 'duplicate ranges' do
          let(:informal_conference_times) { [all_time_ranges[1], all_time_ranges[1]] }

          it('HAS ERRORS') { expect(errors).not_to be_empty }
        end
      end
    end
  end

  context 'included:' do
    it('has no errors') { expect(errors).to be_empty }

    context 'duplicate ContestableIssues' do
      let(:included) { [included_template[0], included_template[0]] }

      it('HAS ERRORS') { expect(errors).not_to be_empty }
    end

    context 'duplicate ContestableIssues' do
      let(:included) do
        [
          {
            type: 'ContestableIssue',
            attributes: {
              decisionDate: '2020-01-01',
              decisionIssueId: 1,
              ratingIssueId: '2',
              ratingDecisionIssueId: '3',
              issue: 'hello'
            }
          },
          {
            type: 'ContestableIssue',
            attributes: {
              issue: 'hello',
              ratingDecisionIssueId: '3',
              decisionIssueId: 1,
              ratingIssueId: '2',
              decisionDate: '2020-01-01'
            }
          }
        ]
      end

      it('HAS ERRORS') { expect(errors).not_to be_empty }
    end
  end
end
