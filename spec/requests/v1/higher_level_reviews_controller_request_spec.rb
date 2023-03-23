# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V1::HigherLevelReviewsController do
  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  before { sign_in_as(user) }

  describe '#create' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?', 'V1::HigherLevelReviewsController#create exception % (HLR_V1)'
    end

    subject do
      post '/v1/higher_level_reviews',
           params: VetsJsonSchema::EXAMPLES.fetch('HLR-CREATE-REQUEST-BODY_V1').to_json,
           headers:
    end

    it 'creates an HLR' do
      VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-200_V1') do
        subject
        expect(response).to be_successful
        appeal_uuid = JSON.parse(response.body)['data']['id']
        expect(AppealSubmission.where(submitted_appeal_uuid: appeal_uuid).first).to be_truthy
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-422_V1') do
        expect(personal_information_logs.count).to be 0
        subject
        expect(personal_information_logs.count).to be 1
        pil = personal_information_logs.first
        %w[
          first_name last_name birls_id icn edipi mhv_correlation_id
          participant_id vet360_id ssn assurance_level birth_date
        ].each { |key| expect(pil.data['user'][key]).to be_truthy }
        %w[message backtrace key response_values original_status original_body]
          .each { |key| expect(pil.data['error'][key]).to be_truthy }
        expect(pil.data['additional_data']['request']['body']).not_to be_empty
      end
    end
  end
end
