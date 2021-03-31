# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::NoticeOfDisagreementsController, type: :request do
  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  before { sign_in_as(user) }

  it('is present') { expect(described_class).to be_truthy }

  describe '#show' do
    subject { get "/v0/notice_of_disagreements/#{uuid}" }

    let(:uuid) { '1234567a-89b0-123c-d456-789e01234f56' }

    it 'shows an HLR' do
      VCR.use_cassette('decision_review/NOD-SHOW-RESPONSE-200') do
        subject
        expect(response).to be_successful
        expect(JSON.parse(response.body)['data']['id']).to eq uuid
      end
    end
  end
end
