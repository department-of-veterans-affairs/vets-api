# frozen_string_literal: true

require 'rails_helper'

describe EVSS::VsoSearch::Service do
  let(:user) { create(:evss_user) }
  let(:service) { described_class.new(user) }
  let(:response) { OpenStruct.new(body: get_fixture('json/veteran_with_poa')) }

  def it_returns_valid_payload(method, form = nil)
    allow(service).to receive(:perform).and_return(response)
    service.send(*[method, form].compact)
  end

  def it_handles_errors(method, form = nil, form_id = nil)
    allow(service).to receive(:perform).and_raise(Faraday::ParsingError)
    expect(service).to receive(:handle_error)
    service.send(*[method, form, form_id].compact)
  end

  describe '#get_current_info' do
    it 'with a valid evss response' do
      it_returns_valid_payload(:get_current_info, response.body)
    end

    it 'handles errors' do
      it_handles_errors(:get_current_info, response.body)
    end
  end
end
