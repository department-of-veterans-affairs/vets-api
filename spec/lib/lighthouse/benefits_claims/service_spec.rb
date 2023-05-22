# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/service'

RSpec.describe BenefitsClaims::Service do
  before(:all) do
    @service = BenefitsClaims::Service.new('123498767V234859')
  end

  describe 'making requests' do
    context 'valid requests' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
      end

      describe 'when requesting intent_to_file' do
        it 'retrieves a intent to file from the Lighthouse API' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            response = @service.get_intent_to_file('compensation', '', '')
            expect(response['data']['id']).to eq('193685')
          end
        end
      end
    end
  end
end
