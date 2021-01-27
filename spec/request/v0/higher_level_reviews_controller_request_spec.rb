# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::HigherLevelReviewsController, type: :request do
  context 'with a user' do
    let(:user) { build(:user, :loa3) }
    let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

    before { sign_in_as(user) }

    describe '#create' do
      def personal_information_logs
        PersonalInformationLog.where(
          error_class: 'V0::HigherLevelReviewsController#create exception'
        )
      end

      subject do
        post '/v0/higher_level_reviews',
             params: VetsJsonSchema::EXAMPLES.fetch('HLR-CREATE-REQUEST-BODY').to_json,
             headers: headers
      end

      it 'creates an HLR' do
        VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-200') do
          subject
          expect(response).to be_successful
        end
      end

      it 'adds to the PersonalInformationLog when an exception is thrown' do
        VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-422') do
          expect(personal_information_logs.count).to be 0
          subject
          expect(personal_information_logs.count).to be 1
          pil = personal_information_logs.first
          expect(pil.data['user']).to be_a Hash
          expect(pil.data['user']).not_to be_empty
          expect(pil.data['error']).to be_a Hash
          expect(pil.data['error']).not_to be_empty
          expect(pil.data['request_data']).to be_a Hash
          expect(pil.data['request_data']['body']).to be_a Hash
          expect(pil.data['request_data']['body']).not_to be_empty
        end
      end
    end
  end
end
