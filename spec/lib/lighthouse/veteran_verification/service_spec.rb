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

        Lighthouse::ServiceException::ERROR_MAP.except(422, 499, 501).each do |status, error_class|
          it "throws a #{status} error if Lighthouse sends it back" do
            expect do
              test_error(
                "lighthouse/veteran_verification/disability_rating/#{status == 404 ? '404_ICN' : status}_response"
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

      describe 'when requesting status' do
        let(:icn) { '1012667145V762142' }

        it 'retrieves veteran confirmation status from the Lighthouse API' do
          VCR.use_cassette('lighthouse/veteran_verification/status/200_response') do
            response = @service.get_vet_verification_status(icn, '', '')
            expect(response['data']['id']).to eq('1012667145V762142')
            expect(response['data']['type']).to eq('veteran_status_confirmations')
            expect(response['data']['attributes']['veteran_status']).to eq('confirmed')
          end
        end

        it 'retrieves veteran not confirmed status from the Lighthouse API' do
          VCR.use_cassette('lighthouse/veteran_verification/status/200_not_confirmed_response') do
            response = @service.get_vet_verification_status('1012666182V203559', '', '')
            expect(response['data']['id']).to eq('1012666182V203559')
            expect(response['data']['attributes']['veteran_status']).to eq('not confirmed')
            expect(response['data']['attributes']).to have_key('not_confirmed_reason')
          end
        end

        Lighthouse::ServiceException::ERROR_MAP.except(404, 422, 499, 501).each do |status, error_class|
          it "throws a #{status} error if Lighthouse sends it back" do
            expect do
              test_error(
                "lighthouse/veteran_verification/status/#{status}_response"
              )
            end.to raise_error error_class
          end

          def test_error(cassette_path)
            VCR.use_cassette(cassette_path) do
              @service.get_vet_verification_status(icn, '', '')
            end
          end
        end
      end
    end
  end
end
