# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Dependents::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user) }

  def returns_form(response)
    expect(response['submitProcess'].present?).to eq(true)
  end

  def it_handles_errors(method, form = nil, form_id = nil)
    allow(service).to receive(:perform).and_raise(Faraday::ParsingError)
    expect(service).to receive(:handle_error)
    service.send(*[method, form, form_id].compact)
  end

  describe '#retrieve' do
    it 'should get user details' do
      VCR.use_cassette(
        'evss/dependents/retrieve',
        VCR::MATCH_EVERYTHING
      ) do
        returns_form(service.retrieve.body)
      end
    end

    it 'handles errors' do
      it_handles_errors(:retrieve)
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

    it 'handles errors' do
      it_handles_errors(:clean_form, get_fixture('dependents/retrieve'))
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

    it 'handles errors' do
      it_handles_errors(:validate, get_fixture('dependents/clean_form'))
    end
  end

  describe '#save' do
    it 'should save the form' do
      VCR.use_cassette(
        'evss/dependents/save',
        VCR::MATCH_EVERYTHING
      ) do
        res = service.save(get_fixture('dependents/clean_form'))
        expect(res['formId']).to eq(380_682)
      end
    end

    it 'handles errors' do
      it_handles_errors(:save, get_fixture('dependents/clean_form'))
    end
  end

  describe '#submit' do
    it 'should submit the form' do
      VCR.use_cassette(
        'evss/dependents/submit',
        VCR::MATCH_EVERYTHING
      ) do
        res = service.submit(get_fixture('dependents/clean_form'), 380_682)
        expect(res['submit686Response']['confirmationNumber']).to eq('600138364')
      end
    end

    it 'handles errors' do
      it_handles_errors(:submit, get_fixture('dependents/clean_form'), 380_682)
    end
  end

  describe '#change_evss_times!' do
    it 'converts all epoch times in hash to UTC iso8601 string' do
      input_hash = { 'firstDate' => 1_537_563_190_485, 'dateArray' => [{ 'secondDate' => 1_537_563_190_485 }] }
      expect(
        service.send(:change_evss_times!, input_hash)
      ).to eq(
        'firstDate' => '2018-09-21T20:53:10Z', 'dateArray' => [{ 'secondDate' => '2018-09-21T20:53:10Z' }]
      )
    end
  end

  describe '#convert_ess_time' do
    it 'convertes epoch time to UTC iso8601 string' do
      expect(service.send(:convert_evss_time, 1_537_563_190_485)).to eq('2018-09-21T20:53:10Z')
    end
  end
end
