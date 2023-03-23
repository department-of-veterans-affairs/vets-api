# frozen_string_literal: true

require 'rails_helper'
require 'evss/dependents/service'

describe EVSS::Dependents::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user) }
  let(:transaction_id) { service.transaction_id }

  def returns_form(response)
    expect(response['submitProcess'].present?).to eq(true)
  end

  def it_handles_errors(method, form = nil, form_id = nil)
    allow(service).to receive(:perform).and_raise(Faraday::ParsingError)
    expect(service).to receive(:handle_error)
    service.send(*[method, form, form_id].compact)
  end

  describe '#retrieve' do
    it 'gets user details' do
      VCR.use_cassette(
        'evss/dependents/retrieve',
        erb: { transaction_id: },
        match_requests_on: VCR.all_matches
      ) do
        returns_form(service.retrieve.body)
      end
    end

    it 'handles errors' do
      it_handles_errors(:retrieve)
    end
  end

  describe '#clean_form' do
    it 'cleans the form request' do
      VCR.use_cassette(
        'evss/dependents/clean_form',
        erb: { transaction_id: },
        match_requests_on: VCR.all_matches
      ) do
        returns_form(service.clean_form(get_fixture('dependents/retrieve')))
      end
    end

    it 'handles errors' do
      it_handles_errors(:clean_form, get_fixture('dependents/retrieve'))
    end
  end

  describe '#validate' do
    it 'validates the form' do
      VCR.use_cassette(
        'evss/dependents/validate',
        erb: { transaction_id: },
        match_requests_on: VCR.all_matches
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
    it 'saves the form' do
      VCR.use_cassette(
        'evss/dependents/save',
        erb: { transaction_id: },
        match_requests_on: VCR.all_matches
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
    it 'submits the form' do
      VCR.use_cassette(
        'evss/dependents/submit',
        erb: { transaction_id: },
        match_requests_on: VCR.all_matches
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
