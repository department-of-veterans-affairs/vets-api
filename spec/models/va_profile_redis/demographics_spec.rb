# frozen_string_literal: true

require 'rails_helper'

describe VAProfileRedis::Demographics do
  let(:user) { build(:user, :loa3) }
  let(:demographics_response) do
    # preferred_name comes in a nested structure
    preferred_name = OpenStruct.new(preferred_name: 'ABBI')
    bio_data = OpenStruct.new(preferred_name: preferred_name, birth_date: '1984-07-04', gender_identity: nil)
    raw_response = OpenStruct.new(status: 200, body: { 'bio' => bio_data })

    VAProfile::Demographics::DemographicResponse.from(raw_response)
  end
  let(:demographics_store) { VAProfileRedis::Demographics.for_user(user) }

  describe '#response' do
    context 'when the cache is empty' do
      it 'caches and returns the response', :aggregate_failures do
        allow_any_instance_of(VAProfile::Demographics::Service)
          .to receive(:get_demographics).and_return(demographics_response)
        if VAProfile::Configuration::SETTINGS.demographics.cache_enabled
          expect(demographics_store.redis_namespace).to receive(:set).once
        end
        expect_any_instance_of(VAProfile::Demographics::Service).to receive(:get_demographics).twice
        expect(demographics_store.response.status).to eq 200
        expect(demographics_store.demographics.preferred_name.text).to eq 'ABBI'
      end
    end

    context 'when there is cached data' do
    end
  end
end
