# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user) }

  describe '#retrieve' do
    it 'should get user details' do
      VCR.use_cassette(
        'evss/dependents/retrieve',
        VCR::MATCH_EVERYTHING
      ) do
        response = service.retrieve
        expect(response.body['submitProcess']['application']['has30Percent']).to eq(true)
      end
    end
  end

  describe '#clean_form' do
    it 'should clean the form request' do
      VCR.use_cassette(
        'evss/dependents/clean_form'
      ) do
        response = service.clean_form(get_fixture('dependents/retrieve'))
        expect(response.body['submitProcess'].present?).to eq(true)
      end
    end
  end
end
