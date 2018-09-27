# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user) }

  def returns_form(response)
    expect(response['submitProcess'].present?).to eq(true)
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
        'evss/dependents/clean_form',
        VCR::MATCH_EVERYTHING
      ) do
        returns_form(service.clean_form(get_fixture('dependents/retrieve')))
      end
    end
  end

  describe '#validate' do
    it 'should validate the form' do
      VCR.use_cassette(
        'evss/dependents/validate',
        VCR::MATCH_EVERYTHING
      ) do
        res = service.validate(get_fixture('dependents/clean_form'))
        expect(res['errors']).to eq([])
      end
    end
  end

  describe '#save' do
    it 'should save the form' do
      VCR.use_cassette(
        'evss/dependents/save',
        VCR::MATCH_EVERYTHING
      ) do
        res = service.save(get_fixture('dependents/clean_form'))
        expect(res['formId']).to eq(380682)
      end
    end
  end

  describe '#submit' do
    it 'should submit the form' do
      VCR.use_cassette(
        'evss/dependents/submit',
        VCR::MATCH_EVERYTHING
      ) do
        res = service.submit(get_fixture('dependents/clean_form'), 380682)
        expect(res['submit686Response']['confirmationNumber']).to eq('600138364')
      end
    end
  end
end
