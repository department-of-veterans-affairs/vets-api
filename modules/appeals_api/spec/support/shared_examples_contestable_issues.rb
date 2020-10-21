# frozen_string_literal: true

RSpec.shared_examples 'contestable issues index requests' do |options|
  let(:get_issues) do
    get(
      "/services/appeals/v1/decision_reviews/#{options[:decision_review_type]}/" \
      "contestable_issues/#{options[:benefit_type]}",
      headers: {
        'X-VA-SSN' => '872958715',
        'X-VA-Receipt-Date' => '2019-12-01'
      }
    )
  end

  describe '#index' do
    it 'GETs contestable_issues from Caseflow successfully' do
      VCR.use_cassette("caseflow/#{options[:decision_review_type]}/contestable_issues") do
        get_issues
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).not_to be nil
      end
    end

    context 'unusable response' do
      before do
        allow_any_instance_of(Caseflow::Service).to(
          receive(:get_contestable_issues).and_return(
            Struct.new(:status, :body).new(
              200,
              '<html>Some html!</html>'
            )
          )
        )
      end

      it 'returns a 502 when Caseflow returns an unusable response' do
        get_issues
        expect(response).to have_http_status(:bad_gateway)
        expect(JSON.parse(response.body)['errors']).to be_an Array
      end
    end

    context 'Caseflow 4XX response' do
      let(:status) { 400 }
      let(:body) { { hello: 'world' }.as_json }

      before do
        allow_any_instance_of(Caseflow::Service).to(
          receive(:get_contestable_issues).and_return(
            Struct.new(:status, :body).new(status, body)
          )
        )
      end

      it 'lets 4XX responses passthrough' do
        get_issues
        expect(response.status).to be status
        expect(JSON.parse(response.body)).to eq body
      end
    end
  end
end
