# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreements::V2::NoticeOfDisagreementsController, type: :request do
  describe '#schema' do
    let(:path) { '/services/appeals/notice_of_disagreements/v2/schemas/10182' }

    it 'renders the json schema' do
      get path
      expect(response.status).to eq(200)

      json_body = JSON.parse response.body
      expect(json_body['description']).to eq('JSON Schema for VA Form 10182')
    end
  end
end
