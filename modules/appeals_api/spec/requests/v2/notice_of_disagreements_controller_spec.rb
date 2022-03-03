# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V2::DecisionReviews::NoticeOfDisagreementsController, type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v2/decision_reviews/#{path}"
  end

  before do
    @max_data = fixture_to_s 'valid_10182_extra.json', version: 'v2'
    @minimum_data = fixture_to_s 'valid_10182_minimum.json', version: 'v2'
    @headers = fixture_as_json 'valid_10182_headers.json', version: 'v2'
    @max_headers = fixture_as_json 'valid_10182_headers_extra.json', version: 'v2'
  end

  let(:parsed) { JSON.parse(response.body) }

  describe '#create' do
    let(:path) { base_path 'notice_of_disagreements' }

    context 'when all headers are present and valid' do
      it 'creates an NOD and persists the data' do
        post(path, params: @max_data, headers: @headers)
        nod = AppealsApi::NoticeOfDisagreement.find_by(id: parsed['data']['id'])

        expect(nod.source).to eq('va.gov')
        expect(parsed['data']['type']).to eq('noticeOfDisagreement')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end
  end
end
