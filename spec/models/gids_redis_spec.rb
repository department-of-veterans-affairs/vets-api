# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe GIDSRedis do
  subject { GIDSRedis.new }
  let(:scrubbed_params) { {} }
  let(:body) { {} }
  let(:gids_response) do
    GI::GIDSResponse.new(status: 200, body: body)
  end

  describe 'method_missing' do
    it 'returns response body' do
      allow_any_instance_of(GI::Client).to receive(:get_institution_details).and_return(gids_response)

      expect(subject.get_institution_details(scrubbed_params)).to eq(gids_response.body)
    end

    it 'undefined method' do
      # expect().to raise_error does not work
      # expect(subject.not_a_real_method()).to raise_error(NoMethodError)
      begin
        subject.not_a_real_method()
      rescue NoMethodError => error
          expect(error).to be_instance_of(NoMethodError)
      end
    end
  end
  
  describe 'cached attributes' do
    context "get_calculator_constants" do

      context 'when the cache is empty' do
        it 'caches and return the response', :aggregate_failures do
          VCR.use_cassette('gi_client/get_calculator_constants') do
            expect(subject.redis_namespace).to receive(:set).once
            response = subject.get_calculator_constants(scrubbed_params)
            expect(response).to be_a(Hash)
          end
        end
      end

      context 'when there is cached data' do
        it 'returns the cached data', :aggregate_failures do

          subject.cache(
              :get_calculator_constants.to_s + scrubbed_params.to_s,
              gids_response
          )
          binding.pry
          expect_any_instance_of(GI::Client).not_to receive(:get_calculator_constants).with(scrubbed_params)
          expect(subject.get_calculator_constants(scrubbed_params)).to be_a(GI::Responses::GIDSResponse)
        end
      end
    end
  end
end
