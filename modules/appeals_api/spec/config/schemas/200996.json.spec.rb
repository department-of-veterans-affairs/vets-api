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

  let(:errors) { validator.validate(json).to_a }

  let(:validator) { JSONSchemer.schema(json_schema) }

  let(:json) { hash.as_json }

  it { expect(json_schema).to be_a Hash }

  it { expect(validator).to be_truthy }

  context 'minimum object' do
    let(:hash) do
      {
        data: {
          type: 'HigherLevelReview',
          attributes: {
            informalConference: false,
            sameOffice: false,
            legacyOptInApproved: true,
            benefitType: 'compensation',
          }
        },
        included: [
          {
            type: 'ContestableIssue',
            attributes: {
              decisionIssueId: 205
            }
          }
        ]
      }
    end

    it { expect(errors).to be_empty }
  end

  context "veteran's address" do
    let(:hash) do
      {
        data: {
          type: 'HigherLevelReview',
          attributes: {
            informalConference: false,
            sameOffice: false,
            legacyOptInApproved: true,
            benefitType: 'compensation',
            veteran: veteran
          }
        },
        included: [
          {
            type: 'ContestableIssue',
            attributes: {
              decisionIssueId: 205
            }
          }
        ]
      }
    end

    context 'required address fields (if address fields are present)' do
      context 'no address fields present' do
        context 'address is nil' do
          let(:veteran) { { address: nil } }

          it('has errors') { expect(errors).not_to be_empty }
        end

        context 'address is empty object' do
          let(:veteran) { { address: {} } }

          it('has errors') { expect(errors).not_to be_empty }
        end
      end

      context 'address_type: DOMESTIC' do
        let(:veteran) do
          {
            address: {
              "address_type": 'DOMESTIC'
            }.merge(fields)
          }
        end

        context 'no other address fields present' do
          let(:fields) { {} }

          it('has errors') { expect(errors).not_to be_empty }
        end
      end
    end
  end
end
