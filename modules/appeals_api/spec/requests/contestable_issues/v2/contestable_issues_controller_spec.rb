# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::ContestableIssues::V2::ContestableIssuesController, type: :request do
  describe '#schema' do
    let(:path) { '/services/appeals/contestable_issues/v2/schemas/headers' }

    it 'renders the json schema for request headers' do
      get path
      expect(response.status).to eq(200)

      json_body = JSON.parse response.body
      expect(json_body['description']).to eq(
        'JSON Schema for Contestable Issues endpoint headers (Decision Reviews API)'
      )
    end
  end
end
