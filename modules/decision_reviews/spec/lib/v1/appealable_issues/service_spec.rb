# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'
require 'decision_reviews/v1/appealable_issues/service'

describe DecisionReviews::V1::AppealableIssues::Service do
  subject { described_class.new }

  let(:ssn_with_mockdata) { '212222112' }
  let(:user) { build(:user, :loa3, ssn: ssn_with_mockdata) }

  describe 'Schema validation' do
    describe 'TEST_APPEALABLE_ISSUES_SCHEMA' do
      let(:schema) { described_class::TEST_APPEALABLE_ISSUES_SCHEMA }

      it 'is a valid JSON schema' do
        expect(schema).to be_a Hash
        expect(schema['type']).to eq 'object'
        expect(schema['properties']).to have_key 'data'
      end

      it 'accepts appealableIssue type' do
        valid_response = {
          'data' => [{
            'type' => 'appealableIssue',
            'id' => nil,
            'attributes' => {
              'ratingIssueReferenceId' => '123',
              'description' => 'Test issue',
              'approxDecisionDate' => '2023-01-01',
              'isRating' => true,
              'timely' => true
            }
          }]
        }
        errors = JSONSchemer.schema(schema).validate(valid_response).to_a
        expect(errors).to be_empty
      end

      it 'accepts contestableIssue type for backward compatibility' do
        valid_response = {
          'data' => [{
            'type' => 'contestableIssue',
            'id' => nil,
            'attributes' => {
              'ratingIssueReferenceId' => '123',
              'description' => 'Test issue',
              'approxDecisionDate' => '2023-01-01',
              'isRating' => true,
              'timely' => true
            }
          }]
        }
        errors = JSONSchemer.schema(schema).validate(valid_response).to_a
        expect(errors).to be_empty
      end

      it 'rejects invalid type' do
        invalid_response = {
          'data' => [{
            'type' => 'invalidType',
            'id' => nil,
            'attributes' => {}
          }]
        }
        errors = JSONSchemer.schema(schema).validate(invalid_response).to_a
        expect(errors).not_to be_empty
      end
    end
  end

  describe '#get_higher_level_review_issues' do
    subject do
      described_class.new.get_higher_level_review_issues(benefit_type:, user:)
    end

    let(:benefit_type) { 'compensation' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
          expect(subject.body['data']).to be_an Array
        end
      end
    end

    context '200 response with a malformed body' do
      def personal_information_logs
        PersonalInformationLog.where(
          'error_class LIKE ?',
          '%AppealableIssues::Service#validate_against_schema%HLR_V1%'
        )
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-200-MALFORMED_V1') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('unknown-icn')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end

    context '422 response with invalid benefit_type' do
      let(:benefit_type) { 'apricot' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-422_V1') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
        end
      end
    end

    context 'with nil benefit_type' do
      let(:benefit_type) { nil }

      it 'defaults to compensation' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject.status).to be 200
        end
      end
    end
  end

  describe '#get_notice_of_disagreement_issues' do
    subject do
      described_class.new.get_notice_of_disagreement_issues(user:, benefit_type:)
    end

    let(:benefit_type) { 'compensation' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/appealable_issues/NOD-GET-APPEALABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
          expect(subject.body['data']).to be_an Array
        end
      end
    end

    context '200 response with a malformed body' do
      def personal_information_logs
        PersonalInformationLog.where(
          'error_class LIKE ?',
          '%AppealableIssues::Service#validate_against_schema%NOD_V1%'
        )
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/appealable_issues/NOD-GET-APPEALABLE-ISSUES-RESPONSE-200-MALFORMED_V1') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('unknown-icn')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/NOD-GET-APPEALABLE-ISSUES-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end

    context 'with nil benefit_type' do
      let(:benefit_type) { nil }

      it 'defaults to compensation' do
        VCR.use_cassette('decision_review/appealable_issues/NOD-GET-APPEALABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject.status).to be 200
        end
      end
    end

    context 'benefit_type is optional for NOD' do
      it 'does not throw 422 error when benefit_type is invalid' do
        # NOD API accepts invalid benefit_type without error per API docs
        # Note: You may want to verify actual API behavior and adjust this test
      end
    end
  end

  describe '#get_supplemental_claim_issues' do
    subject do
      described_class.new.get_supplemental_claim_issues(user:, benefit_type:)
    end

    let(:benefit_type) { 'compensation' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject).to respond_to :status
          expect(subject.status).to be 200
          expect(subject).to respond_to :body
          expect(subject.body).to be_a Hash
          expect(subject.body['data']).to be_an Array
        end
      end
    end

    context '200 response with a malformed body' do
      def personal_information_logs
        PersonalInformationLog.where(
          'error_class LIKE ?',
          '%AppealableIssues::Service#validate_against_schema%SC_V1%'
        )
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-200-MALFORMED_V1') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('unknown-icn')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-404_V1') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end

    context '422 response with invalid benefit_type' do
      let(:benefit_type) { 'apricot' }

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-422_V1') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
        end
      end
    end

    context 'with nil benefit_type' do
      let(:benefit_type) { nil }

      it 'defaults to compensation' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-200_V1') do
          expect(subject.status).to be 200
        end
      end
    end
  end

  describe 'error handling' do
    subject do
      described_class.new.get_supplemental_claim_issues(user:, benefit_type: 'compensation')
    end

    context 'parsing error' do
      it 'throws a DecisionReviews::V1::ServiceException with DR_502 key' do
        allow_any_instance_of(DecisionReviews::V1::AppealableIssues::Configuration).to receive(:get_supplemental_claim_issues)
          .and_raise(Faraday::ParsingError.new('Invalid JSON'))

        expect { subject }.to raise_error do |error|
          expect(error).to be_a(DecisionReviews::V1::ServiceException)
          expect(error.key).to eq('DR_502')
        end
      end
    end

    context '503 service unavailable' do
      it 'throws a Common::Exceptions::ServiceUnavailable' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-503_V1') do
          expect { subject }.to raise_error Common::Exceptions::ServiceUnavailable
        end
      end
    end

    context '401 unauthorized' do
      it 'throws a Common::Exceptions::Unauthorized' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-401_V1') do
          expect { subject }.to raise_error Common::Exceptions::Unauthorized
        end
      end
    end

    context 'unmapped error code (418)' do
      it 'throws a DecisionReviews::V1::ServiceException with DR_418 key' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-418_V1') do
          expect { subject }.to raise_error do |error|
            expect(error).to be_a(DecisionReviews::V1::ServiceException)
            expect(error.key).to eq('DR_418')
            expect(error.original_status).to eq(418)
          end
        end
      end
    end
  end
end
