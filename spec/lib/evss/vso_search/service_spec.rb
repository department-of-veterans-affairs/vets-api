# frozen_string_literal: true

require 'rails_helper'

describe EVSS::VsoSearch::Service do
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

  describe '#get_current_info' do
    it 'handles errors' do
      it_handles_errors(:get_current_info, get_fixture('json/veteran_with_poa'))
    end
  end
end
