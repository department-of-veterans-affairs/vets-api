# frozen_string_literal: true

require 'rails_helper'
require 'decision_review/service'

describe DecisionReview::Service do
  subject { described_class.new }

  let(:ssn_with_mockdata) { '212222112' }
  let(:user) { build(:user, :loa3, ssn: ssn_with_mockdata) }

  describe '#post_higher_level_reviews' do
    context 'with a valid decision review request' do
      it 'returns an intake status response object' do
        VCR.use_cassette('decision_review/202_intake_status') do
          request = {
            'data' => {
              'type' => 'HigherLevelReview',
              'attributes' => {
                'receiptDate' => '2019-07-10',
                'informalConference' => true,
                'sameOffice' => false,
                'legacyOptInApproved' => true,
                'benefitType' => 'compensation',
                'veteran' => {
                  'fileNumberOrSsn' => '123456789',
                  'addressLine1' => '123 Street St',
                  'addressLine2' => 'Apt 4',
                  'city' => 'Chicago',
                  'stateProvinceCode' => 'IL',
                  'zipPostalCode' => '60652',
                  'phoneNumber' => '4432924565',
                  'emailAddress' => 'someone@example.com'
                },
                'claimant' => {
                  'participantId' => '44444444',
                  'payeeCode' => '10'
                }
              }
            },
            'included' => [
              {
                'type' => 'RequestIssue',
                'attributes' => {
                  'decisionIssueId' => 2
                }
              }
            ]
          }

          response = subject.post_higher_level_reviews(request.to_json)
          expect(response).to be_accepted
          expect(response).to be_an DecisionReview::Responses::Response
        end
      end
    end

    context 'with a malformed decision review request' do
      it 'returns a 400 error' do
        VCR.use_cassette('decision_review/400_intake_status') do
          expect(StatsD).to receive(:increment).once.with(
            'api.decision_review.post_higher_level_reviews.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:400'
            ]
          )
          expect(StatsD).to receive(:increment).once.with('api.decision_review.post_higher_level_reviews.total')
          expect { subject.post_higher_level_reviews({}) }.to raise_error(DecisionReview::ServiceException)
        end
      end
    end

    context 'with a non-existend veteran request' do
      it 'logs an error and raises an exception' do
        VCR.use_cassette('decision_review/404_intake_status') do
          request = {
            'data' => {
              'type' => 'HigherLevelReview',
              'attributes' => {
                'receiptDate' => '2019-07-10',
                'informalConference' => true,
                'sameOffice' => false,
                'legacyOptInApproved' => true,
                'benefitType' => 'compensation'
              },
              'relationships' => {
                'veteran' => {
                  'data' => {
                    'type' => 'Veteran',
                    'id' => '00000000'
                  }
                }
              }
            },
            'included' => [
              {
                'type' => 'RequestIssue',
                'attributes' => {
                  'decisionIssueId' => 2
                }
              }
            ]
          }
          expect(StatsD).to receive(:increment).once.with(
            'api.decision_review.post_higher_level_reviews.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:404'
            ]
          )
          expect(StatsD).to receive(:increment).once.with('api.decision_review.post_higher_level_reviews.total')
          expect { subject.post_higher_level_reviews(request) }.to raise_error(DecisionReview::ServiceException)
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'logs an error and raise GatewayTimeout exception' do
        expect(StatsD).to receive(:increment).once.with(
          'api.decision_review.post_higher_level_reviews.fail', tags: ['error:CommonExceptionsGatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.decision_review.post_higher_level_reviews.total')
        expect { subject.post_higher_level_reviews({}) }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'with a bad API key' do
      it 'returns a 401 error' do
        VCR.use_cassette('decision_review/401_intake_status', match_requests_on: %i[path query]) do
          expect { subject.post_higher_level_reviews({}) }
            .to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(502)
            expect(e.errors.first[:detail]).to eq('Invalid api_key for the upstream server')
            expect(e.errors.first[:code]).to eq('DR_401')
          end
        end
      end
    end

    context 'when service returns a 403' do
      it 'logs the error and raises an exception' do
        VCR.use_cassette('decision_review/403_intake_status') do
          expect(StatsD).to receive(:increment).once.with(
            'api.decision_review.post_higher_level_reviews.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:403'
            ]
          )
          expect(StatsD).to receive(:increment).once.with('api.decision_review.post_higher_level_reviews.total')
          expect { subject.post_higher_level_reviews({}) }.to raise_error(Common::Exceptions::Forbidden)
        end
      end
    end
  end

  describe '#get_higher_level_reviews_intake_status' do
    context 'with a valid decision review response' do
      it 'returns an intake status response object' do
        VCR.use_cassette('decision_review/200_intake_status') do
          response = subject.get_higher_level_reviews_intake_status('1234567890')
          expect(response).to be_ok
          expect(response).to be_an DecisionReview::Responses::Response
        end
      end
    end

    context 'with a decision response that does not exist' do
      it 'returns a 404 error' do
        VCR.use_cassette('decision_review/404_get_intake_status') do
          expect(StatsD).to receive(:increment).once.with(
            'api.decision_review.get_higher_level_reviews_intake_status.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:404'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.decision_review.get_higher_level_reviews_intake_status.total'
          )
          expect { subject.get_higher_level_reviews_intake_status('1234') }.to raise_error(
            DecisionReview::ServiceException
          )
        end
      end
    end
  end

  describe '#get_higher_level_reviews' do
    context 'with a valid higher review response' do
      it 'returns an review response object' do
        VCR.use_cassette('decision_review/200_review') do
          response = subject.get_higher_level_reviews('4bc96bee-c6a3-470e-b222-66a47629dc20')
          expect(response).to be_ok
          expect(response).to be_an DecisionReview::Responses::Response
        end
      end
    end

    context 'with a higher review response id that does not exist' do
      it 'returns a 404 error' do
        VCR.use_cassette('decision_review/404_review') do
          expect(StatsD).to receive(:increment).once.with(
            'api.decision_review.get_higher_level_reviews.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:404'
            ]
          )
          expect(StatsD).to receive(:increment).once.with(
            'api.decision_review.get_higher_level_reviews.total'
          )
          expect { subject.get_higher_level_reviews('1234') }.to raise_error(
            DecisionReview::ServiceException
          )
        end
      end
    end
  end

  describe '#get_contestable_issues' do
    context 'with a valid contestable issues request' do
      it 'returns a contestable issues response object' do
        VCR.use_cassette('decision_review/200_contestable_issues') do
          response = subject.get_contestable_issues(user)
          expect(response).to be_ok
          expect(response).to be_an DecisionReview::Responses::Response
        end
      end
    end

    context 'when service returns a 422' do
      it 'logs the error and raises an exception' do
        VCR.use_cassette('decision_review/422_contestable_issues') do
          expect(StatsD).to receive(:increment).once.with(
            'api.decision_review.get_contestable_issues.fail', tags: [
              'error:CommonClientErrorsClientError', 'status:422'
            ]
          )
          expect(StatsD).to receive(:increment).once.with('api.decision_review.get_contestable_issues.total')
          expect { subject.get_contestable_issues(user) }.to raise_error(DecisionReview::ServiceException)
        end
      end
    end
  end
end
