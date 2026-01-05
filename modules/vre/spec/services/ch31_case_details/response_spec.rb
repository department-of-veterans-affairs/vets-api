# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::Ch31CaseDetails::Response do
  subject(:response) { described_class.new(raw_response.status, raw_response) }

  let(:json) { File.read('modules/vre/spec/fixtures/ch31_case_details.json') }
  let(:body) { JSON.parse(json).deep_transform_keys!(&:underscore) }
  let(:raw_response) { instance_double(Faraday::Env, status: 200, body:) }

  describe '#initialize' do
    it 'sets attributes from raw response' do
      expect(response.attributes).to eq(body)
    end
  end
end
