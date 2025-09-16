# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::Ch31Eligibility::Response do
  subject(:response) { described_class.new(raw_response.status, raw_response) }

  let(:body) { File.read('modules/vre/spec/fixtures/ch31_eligibility.json') }
  let(:raw_response) { instance_double(Faraday::Response, status: 200, body:) }

  describe '#initialize' do
  end
end
