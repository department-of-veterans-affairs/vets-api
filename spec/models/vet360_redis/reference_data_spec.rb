# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe Vet360Redis::ReferenceData do
  subject { Vet360Redis::ReferenceData.new }

  describe 'cached attributes' do
    %i[countries states zipcodes].each do |method|
      context "##{method}" do
        context 'when the cache is empty' do
          it 'should cache and return the response', :aggregate_failures do
            VCR.use_cassette("vet360/reference_data/#{method}", VCR::MATCH_EVERYTHING) do
              expect(subject.redis_namespace).to receive(:set).once
              response = subject.public_send(method)
              expect(response.public_send(method)).to be_a(Array)
            end
          end
        end

        context 'when there is cached data' do
          it 'returns the cached data', :aggregate_failures do
            response_type = "Vet360::ReferenceData::#{method.to_s.titleize}Response".constantize

            subject.cache(
              "vet360_reference_data_#{method}",
              response_type.new(200, reference_data: [])
            )

            expect_any_instance_of(Vet360::ReferenceData::Service).not_to receive(method)
            expect(subject.public_send(method)).to be_a(response_type)
          end
        end
      end
    end
  end
end
