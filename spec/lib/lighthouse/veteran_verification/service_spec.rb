# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/veteran_verification/service'

RSpec.describe VeteranVerification::Service do
  before(:all) do
    @service = VeteranVerification::Service.new
  end

  describe 'making requests' do
    context 'valid requests' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
      end

      describe 'when requesting disability_rating' do
        it 'retrieves rated disabilities from the Lighthouse API' do
          VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
            auth_params = {
              launch: Base64.encode64(JSON.generate({ patient: '123498767V234859' }, space: ' '))
            }
            response = @service.get_rated_disabilities('', '', { auth_params: })
            expect(response['data']['id']).to eq('12303')
          end
        end
      end
    end
  end
end
