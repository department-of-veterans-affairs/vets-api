# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::AppealableIssues::V0::AppealableIssuesController, type: :request do
  describe '#schema' do
    let(:path) { '/services/appeals/appealable-issues/v0/schemas/appealable-issues' }

    it 'renders the json schema for request body with shared refs' do
      with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['description'])
        .to eq('JSON Schema for Appealable Issues endpoint parameters')
      expect(response.body).to include('{"$ref":"icn.json"}')
    end

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#index' do
    let(:headers) { {} }
    let(:receipt_date) { '2019-12-01' }
    let(:decision_review_type) { 'notice-of-disagreements' }
    let(:benefit_type) {}
    let(:icn) { '1234567890V012345' }
    let(:params) do
      p = {}
      p['receiptDate'] = receipt_date if receipt_date.present?
      p['icn'] = icn if icn.present?
      p['benefitType'] = benefit_type if benefit_type.present?
      p
    end
    let(:json) { JSON.parse(response.body) }
    let(:cassette) { "caseflow/#{decision_review_type.underscore}/contestable_issues" }
    let(:path) { "/services/appeals/appealable-issues/v0/appealable-issues/#{decision_review_type}" }
    let(:mpi_response) { create(:find_profile_response, profile: build(:mpi_profile)) }

    before do
      allow_any_instance_of(MPI::Service)
        .to receive(:find_profile_by_identifier)
        .with(identifier: icn, identifier_type: MPI::Constants::ICN).and_return(mpi_response)

      VCR.use_cassette(cassette) do
        with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
          get(path, headers: auth_header, params:)
        end
      end
    end

    context 'when all required fields provided' do
      it 'fetches contestable_issues from Caseflow successfully' do
        expect(response).to have_http_status(:ok)
        expect(json['data']).not_to be_nil
      end

      it 'replaces the type "contestableIssue" with "appealableIssue" in responses' do
        json['data'].each { |issue| expect(issue['type']).to eq('appealableIssue') }
      end
    end

    describe 'icn parameter' do
      context 'when icn is missing' do
        let(:icn) {}

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          error = json['errors'][0]
          expect(error['detail']).to include('One or more expected fields were not found')
          expect(error['meta']['missing_fields']).to include('icn')
        end
      end

      context 'when icn does not meet length requirements' do
        let(:icn) { '229384' }

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          error = json['errors'][0]
          expect(error['title']).to eql('Invalid length')
          expect(error['detail']).to include("'#{icn}' did not fit within the defined length limits")
        end
      end

      context 'when icn does not meet pattern requirements' do
        let(:icn) { '22938439103910392' }

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          error = json['errors'][0]
          expect(error['title']).to eql('Invalid pattern')
          expect(error['detail']).to include("'#{icn}' did not match the defined pattern")
        end
      end
    end

    describe 'receiptDate parameter' do
      context 'when receipt date is missing' do
        let(:receipt_date) {}

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          error = json['errors'][0]
          expect(error['title']).to eql('Missing required fields')
          expect(error['detail']).to include('One or more expected fields were not found')
        end
      end

      context 'when receipt date is not formatted correctly' do
        let(:receipt_date) { '01/01/2001' }

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          error = json['errors'][0]
          expect(error['title']).to eql('Invalid format')
          expect(error['detail']).to include("'#{receipt_date}' did not match the defined format")
        end
      end
    end

    shared_examples 'benefitType required' do
      context 'when benefitType is invalid' do
        let(:benefit_type) { 'invalid' }

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          error = json['errors'][0]
          expect(error['title']).to eql('Invalid option')
          expect(error['detail']).to eql("'invalid' is not an available option")
        end
      end

      context 'when benefitType is missing' do
        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          error = json['errors'][0]
          expect(error['title']).to eql('Missing required fields')
          expect(error['meta']['missing_fields']).to eql(%w[benefitType])
        end
      end
    end

    context 'with decisionReviewType = HLR' do
      let(:decision_review_type) { 'higher-level-reviews' }

      it_behaves_like 'benefitType required'

      context 'when benefitType is valid' do
        let(:benefit_type) { 'compensation' }

        it 'GETs contestable_issues from caseflow successfully' do
          expect(response).to have_http_status(:ok)
          expect(json['data']).to be_an Array
        end
      end
    end

    context 'with decision_review_type = SC' do
      let(:decision_review_type) { 'supplemental-claims' }

      it_behaves_like 'benefitType required'
    end
  end
end
