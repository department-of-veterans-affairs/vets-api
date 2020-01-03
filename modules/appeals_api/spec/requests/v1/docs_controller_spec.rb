# frozen_string_literal: true

describe AppealsApi::Docs::V1::DocsController, type: :request do
  describe '#decision_reviews' do
    let(:decision_reviews_docs) { '/services/appeals/docs/v1/decision_reviews' }

    it 'successfully returns openapi spec' do
      get decision_reviews_docs
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json['openapi']).to eq('3.0.0')
    end

    describe '/higher_level_reviews documentation' do
      before do
        get decision_reviews_docs
      end
      let(:hlr_doc) do
        json = JSON.parse(response.body)
        json['paths']['/higher_level_reviews']
      end

      it 'supports POST' do
        expect(hlr_doc).to include('post')
      end
    end

    describe '/intake_statuses/{uuid} documentation' do
      before do
        get decision_reviews_docs
      end
      let(:hlr_intake_status_doc) do
        json = JSON.parse(response.body)
        json['paths']['/intake_statuses/{uuid}']
      end

      it 'supports GET' do
        expect(hlr_intake_status_doc).to include('get')
      end
    end

    describe '/higher_level_reviews/{uuid} documentation' do
      before do
        get decision_reviews_docs
      end
      let(:hlr_intake_status_doc) do
        json = JSON.parse(response.body)
        json['paths']['/higher_level_reviews/{uuid}']
      end

      it 'supports GET' do
        expect(hlr_intake_status_doc).to include('get')
      end
    end

    describe '/contestable_issues documentation' do
      before do
        get decision_reviews_docs
      end
      let(:contestable_issues_doc) do
        json = JSON.parse(response.body)
        json['paths']['/contestable_issues']
      end

      it 'supports GET' do
        expect(contestable_issues_doc).to include('get')
      end
    end
  end
end
