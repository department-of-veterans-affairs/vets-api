# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/veteran_verification/service'
require 'lighthouse/service_exception'

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
        let(:icn) { '123498767V234859' }

        it 'retrieves rated disabilities from the Lighthouse API' do
          VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
            response = @service.get_rated_disabilities(icn, '', '')
            expect(response['data']['id']).to eq('12303')
          end
        end

        Lighthouse::ServiceException::ERROR_MAP.each do |status, error_class|
          it "throws a #{status} error if Lighthouse sends it back" do
            expect do
              test_error(
                "lighthouse/veteran_verification/disability_rating/#{status == :'404' ? '404_ICN' : status}_response"
              )
            end.to raise_error error_class
          end

          def test_error(cassette_path)
            VCR.use_cassette(cassette_path) do
              @service.get_rated_disabilities(icn, '', '')
            end
          end
        end

        it 'handles unknown errors' do
          expect do
            test_error(
              'lighthouse/veteran_verification/disability_rating/405_response'
            )
          end.to raise_error Common::Exceptions::ServiceError
        end
      end
    end
  end
end
