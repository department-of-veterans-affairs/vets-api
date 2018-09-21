# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user) }

  def returns_form(response)
    expect(response.body['submitProcess'].present?).to eq(true)
  end

  describe '#retrieve' do
    it 'should get user details' do
      VCR.use_cassette(
        'evss/dependents/retrieve',
        VCR::MATCH_EVERYTHING
      ) do
        returns_form(service.retrieve)
      end
    end
  end

  describe '#clean_form' do
    it 'should clean the form request' do
      VCR.use_cassette(
        'evss/dependents/clean_form'
      ) do
        returns_form(service.clean_form(get_fixture('dependents/retrieve')))
      end
    end
  end
end
