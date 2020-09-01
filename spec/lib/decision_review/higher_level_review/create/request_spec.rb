# frozen_string_literal: true

require_relative '../../../../../lib/decision_review/request.rb'
require_relative '../../../../../lib/decision_review/higher_level_review/create/request.rb'
require_relative '../../../../../lib/decision_review/request_schema_error.rb'
require_relative '../../../../../lib/decision_review/schema_error.rb'
require 'rails_helper'

describe DecisionReview::HigherLevelReview::Create::Request do
  let(:data) { Struct.new(:headers, :body).new headers, body }

  let(:headers) do
    {
      'X-VA-SSN' => '123456789',
      'X-VA-First-Name' => 'Jane',
      'X-VA-Middle-Initial' => 'Z',
      'X-VA-Last-Name' => 'Doe',
      'X-VA-Birth-Date' => '1970-01-01'
    }
  end

  let(:body) do
    JSON.parse <<~HEREDOC
      {
        "data": {
          "type": "higherLevelReview",
          "attributes": {
            "informalConference": true,
            "sameOffice": true,
            "benefitType": "compensation",
            "veteran": {
              "address": { "zipCode5": "66002" },
              "phone": {
                "countryCode": "34",
                "areaCode": "555",
                "phoneNumber": "8001111",
                "phoneNumberExt": "2"
              },
              "emailAddressText": "josie@example.com",
              "timezone": "America/Chicago"
            },
            "informalConferenceTimes": [
              "1230-1400 ET",
              "1400-1630 ET"
            ],
            "informalConferenceRep": {
              "name": "Helen Holly",
              "phone": {
                "countryCode": "6",
                "areaCode": "555",
                "phoneNumber": "8001111",
                "phoneNumberExt": "2"
              }
            }
          }
        },
        "included": [
          {
            "type": "contestableIssue",
            "attributes": {
              "issue": "tinnitus",
              "decisionDate": "1900-01-01",
              "decisionIssueId": 1,
              "ratingIssueReferenceId": "2",
              "ratingDecisionReferenceId": "3"
            }
          },
          {
            "type": "contestableIssue",
            "attributes": {
              "issue": "left knee",
              "decisionDate": "1900-01-02",
              "decisionIssueId": 4,
              "ratingIssueReferenceId": "5"
            }
          },
          {
            "type": "contestableIssue",
            "attributes": {
              "issue": "right knee",
              "decisionDate": "1900-01-03",
              "ratingIssueReferenceId": "6",
              "ratingDecisionReferenceId": "7"
            }
          },
          {
            "type": "contestableIssue",
            "attributes": {
              "issue": "PTSD",
              "decisionDate": "1900-01-04",
              "decisionIssueId": 8,
              "ratingDecisionReferenceId": "9"
            }
          },
          {
            "type": "contestableIssue",
            "attributes": {
              "issue": "Traumatic Brain Injury",
              "decisionDate": "1900-01-05",
              "decisionIssueId": 10
            }
          },
          {
            "type": "contestableIssue",
            "attributes": {
              "issue": "right shoulder",
              "decisionDate": "1900-01-06"
            }
          }
        ]
      }
    HEREDOC
  end

  describe '#initialize' do
    it 'creates a request object when given valid input' do
      expect(described_class.new(data)).to be_truthy
    end
  end

  describe '#schema_errors' do
    subject do
      described_class.new(data)
    rescue => e
      e
    end

    let(:body) { 'Hi!' }

    it 'throws a RequestSchemaError' do
      expect(subject).to be_a DecisionReview::RequestSchemaError
    end

    it 'has errors' do
      expect(subject.errors).to be_a Array
      expect(subject.errors).not_to be_empty
    end
  end

  describe '#perform_args' do
    subject { described_class.new(data) }

    it 'returns the arguments needed for the perform method' do
      expect(subject.perform_args).to be_an Array
      expect(subject.perform_args.third).to eq subject.data.body
      expect(subject.perform_args.fourth).to eq subject.data.headers
    end
  end
end
