# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'
require 'decision_reviews/v1/appealable_issues/service'

describe DecisionReviews::V1::AppealableIssues::Service do
  subject { described_class.new }

  let(:ssn_with_mockdata) { '212222112' }
  let(:user) { build(:user, :loa3, ssn: ssn_with_mockdata) }

  before do
    Timecop.freeze(Time.zone.parse('2026-01-23T00:00:00Z'))
    allow_any_instance_of(DecisionReviews::V1::AppealableIssues::Configuration)
      .to receive(:access_token).and_return('fake_token')
    allow_any_instance_of(User).to receive(:icn).and_return('1012832025V743496')
  end

  after do
    Timecop.return
  end

  describe 'VetsJsonSchema used in service' do
    describe 'ensure Appealable Issues schemas are present' do
      %w[
        DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1
      ].each do |schema_name|
        it("#{schema_name} schema is present") { expect(VetsJsonSchema::SCHEMAS[schema_name]).to be_a Hash }
      end
    end

    describe 'ensure Appealable Issues schema examples are present' do
      %w[
        DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1
      ].each do |schema_name|
        it("#{schema_name} schema example is present") { expect(VetsJsonSchema::EXAMPLES).to have_key schema_name }
      end
    end
  end

  describe '#get_higher_level_review_issues' do
    subject do
      described_class.new.get_higher_level_review_issues(user:, benefit_type:)
    end

    let(:benefit_type) { 'compensation' }

    context '200 response' do
      it 'returns a properly formatted 200 response' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-200') do
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
        PersonalInformationLog.where error_class:
          'DecisionReviews::V1::AppealableIssues::Service#validate_against_schema' \
          ' exception Common::Exceptions::SchemaValidationErrors (HLR_V1)'
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-200-MALFORMED') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('0000000000V000000')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-404') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end

    context '422 response with invalid benefit_type' do
      let(:benefit_type) { 'apricot' }

      before do
        allow_any_instance_of(User).to receive(:icn).and_return('2331123616V514303')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/HLR-GET-APPEALABLE-ISSUES-RESPONSE-422') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
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
        VCR.use_cassette('decision_review/appealable_issues/NOD-GET-APPEALABLE-ISSUES-RESPONSE-200') do
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
        PersonalInformationLog.where error_class:
          'DecisionReviews::V1::AppealableIssues::Service#validate_against_schema' \
          ' exception Common::Exceptions::SchemaValidationErrors (NOD_V1)'
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/appealable_issues/NOD-GET-APPEALABLE-ISSUES-RESPONSE-200-MALFORMED') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('0000000000V000000')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/NOD-GET-APPEALABLE-ISSUES-RESPONSE-404') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end

    context '422 response with invalid benefit_type' do
      let(:benefit_type) { 'apricot' }

      before do
        allow_any_instance_of(User).to receive(:icn).and_return('2331123616V514303')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/NOD-GET-APPEALABLE-ISSUES-RESPONSE-422') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
        end
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
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-200') do
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
        PersonalInformationLog.where error_class:
          'DecisionReviews::V1::AppealableIssues::Service#validate_against_schema' \
          ' exception Common::Exceptions::SchemaValidationErrors (SC_V1)'
      end

      it 'returns a schema error' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-200-MALFORMED') do
          expect(personal_information_logs.count).to be 0
          expect { subject }.to raise_error an_instance_of Common::Exceptions::SchemaValidationErrors
          expect(personal_information_logs.count).to be 1
        end
      end
    end

    context '404 response' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('0000000000V000000')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-404') do
          expect { subject }.to raise_error Common::Exceptions::ResourceNotFound
        end
      end
    end

    context '422 response with invalid benefit_type' do
      let(:benefit_type) { 'apricot' }

      before do
        allow_any_instance_of(User).to receive(:icn).and_return('2331123616V514303')
      end

      it 'throws a Common::Exception' do
        VCR.use_cassette('decision_review/appealable_issues/SC-GET-APPEALABLE-ISSUES-RESPONSE-422') do
          expect { subject }.to raise_error Common::Exceptions::UnprocessableEntity
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
        allow_any_instance_of(DecisionReviews::V1::AppealableIssues::Service).to receive(:perform)
          .and_raise(Faraday::ParsingError.new('Invalid JSON'))

        expect { subject }.to raise_error do |error|
          expect(error).to be_a(DecisionReviews::V1::ServiceException)
          expect(error.key).to eq('DR_502')
        end
      end
    end
  end
end
