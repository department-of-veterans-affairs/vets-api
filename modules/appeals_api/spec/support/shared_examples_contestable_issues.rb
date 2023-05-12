# frozen_string_literal: true

require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.shared_examples 'Appealable Issues API v0 and Decision Reviews v1 & v2 shared request examples' do |base_path: ''|
  describe '#index' do
    let(:ssn) { '872958715' }
    let(:icn) do
      # Appealable Issues API V0 requires ICN, others do not
      base_path.include?('v0') ? '1234567890V012345' : nil
    end
    let(:file_number) { nil }
    let(:receipt_date) { '2019-12-01' }
    let(:decision_review_type) { base_path.include?('v1') ? 'notice_of_disagreements' : 'higher_level_reviews' }
    let(:benefit_type) { base_path.include?('v1') ? '' : 'compensation' }
    let(:cassette) { nil }

    let(:path) do
      if base_path.include? 'v1'
        # NOD does not use benefit type, and its decision review type is constant
        base_path
      else
        "#{base_path}/#{decision_review_type}?benefit_type=#{benefit_type}"
      end
    end
    let(:headers) do
      h = {}
      h['X-VA-Receipt-Date'] = receipt_date if receipt_date.present?
      h['X-VA-ICN'] = icn if icn.present?
      h['X-VA-File-Number'] = file_number if file_number.present?
      h['X-VA-SSN'] = ssn if ssn.present?
      h
    end
    let(:body) { JSON.parse(response.body) }
    let(:scopes) do
      if described_class.const_defined? :OAUTH_SCOPES
        described_class::OAUTH_SCOPES[:GET]
      else
        %w[]
      end
    end

    if described_class.const_defined? :OAUTH_SCOPES
      let(:cassette) { "caseflow/#{decision_review_type}/contestable_issues" }

      it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
        def make_request(auth_header)
          VCR.use_cassette(cassette) { get(path, headers: headers.merge(auth_header)) }
        end
      end
    end

    context 'header validations' do
      before { get_appealable_issues }

      context 'when X-VA-Receipt-Date is missing' do
        let(:receipt_date) { nil }

        it 'returns a 422' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(body['errors']).to be_an Array
        end
      end

      context 'when X-VA-SSN and X-VA-File-Number are missing' do
        let(:ssn) { nil }

        it 'returns a 422' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(body['errors']).to be_an Array
        end
      end

      context 'when X-VA-SSN is invalid' do
        let(:ssn) { '87295a71b' }

        it 'returns a 422' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(body['errors']).to be_an Array
        end
      end

      context 'when X-VA-ICN is invalid' do
        let(:icn) { '3939s31' }

        it 'returns a 422' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(body['errors']).to be_an Array
        end
      end
    end

    context 'parameter validations' do
      let(:cassette) { "caseflow/#{decision_review_type}/contestable_issues" }

      before { get_appealable_issues }

      unless base_path.include?('v1')
        # Decision Reviews v1 doesn't use benefit type and its decision review type is constant
        context 'when benefit_type is invalid' do
          let(:ssn) { '872958715' }
          let(:benefit_type) { 'invalid-benefit-type' }

          it 'returns a 422' do
            expect(response).to have_http_status(:unprocessable_entity)
            expect(body['errors']).to be_an Array
          end
        end

        context 'when both benefit type and decision review type are invalid' do
          let(:benefit_type) { 'invalid-benefit-type' }
          let(:decision_review_type) { 'invalid-decision-review-type' }

          it 'returns a 422' do
            expect(response).to have_http_status(:unprocessable_entity)
            expect(body['errors']).to be_an Array
          end
        end

        context 'when decision_review_type is invalid' do
          let(:ssn) { '872958715' }
          let(:decision_review_type) { 'invalid-decision-review-type' }

          it 'returns a 422' do
            expect(response).to have_http_status(:unprocessable_entity)
            expect(body['errors']).to be_an Array
          end
        end
      end
    end

    context 'when caseflow responds normally' do
      before { get_appealable_issues }

      context 'when using SSN header as veteran identifier' do
        let(:cassette) { "caseflow/#{decision_review_type}/contestable_issues" }

        it 'GETs contestable_issues from Caseflow successfully' do
          expect(response).to have_http_status(:ok)
          expect(body['data']).not_to be_nil
        end
      end

      context 'when using file_number header as veteran identifier' do
        let(:ssn) { nil }
        let(:file_number) { '123456789' }
        let(:cassette) { "caseflow/#{decision_review_type}/contestable_issues-by-file-number" }

        it 'GETs contestable_issues from Caseflow successfully' do
          expect(response).to have_http_status(:ok)
          expect(body['data']).not_to be_nil
        end
      end
    end

    context 'when caseflow returns a successful but unusable response' do
      let(:unusable_body) { '<html>Some html!</html>' }

      before do
        allow_any_instance_of(Caseflow::Service)
          .to(receive(:get_contestable_issues).and_return(Struct.new(:status, :body).new(200, unusable_body)))
      end

      it 'logs the response and returns a 502 error' do
        expect_any_instance_of(described_class)
          .to receive(:log_caseflow_error).with('UnusableResponse', 200, unusable_body)
        get_appealable_issues
        expect(response).to have_http_status(:bad_gateway)
        expect(body['errors']).to be_an Array
      end
    end

    context 'when caseflow returns a 4XX response' do
      let(:error_body) { { hello: 'world' }.as_json }

      before do
        allow_any_instance_of(Caseflow::Service).to receive(:get_contestable_issues).and_return(
          Struct.new(:status, :body).new(400, error_body)
        )

        get_appealable_issues
      end

      it 'returns the error without modification' do
        expect(response).to have_http_status(:bad_request)
        expect(body).to eq(error_body)
      end
    end

    context 'when Caseflow raises a BackendServiceException' do
      before do
        allow_any_instance_of(Caseflow::Service).to receive(:get_contestable_issues)
          .and_raise(Common::Exceptions::BackendServiceException.new(nil, {}, 503, 'Timeout'))
      end

      it 'logs the error' do
        expect_any_instance_of(described_class).to(
          receive(:log_caseflow_error).with('BackendServiceException', 503, 'Timeout')
        )

        get_appealable_issues
      end
    end

    private

    def get_appealable_issues
      with_openid_auth(scopes) do |auth_header|
        if cassette.present?
          VCR.use_cassette(cassette) { get(path, headers: headers.merge(auth_header)) }
        else
          get(path, headers: headers.merge(auth_header))
        end
      end
    end
  end
end
