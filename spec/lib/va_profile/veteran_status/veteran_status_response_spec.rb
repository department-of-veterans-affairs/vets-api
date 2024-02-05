# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/veteran_status/veteran_status_response'

RSpec.describe VAProfile::VeteranStatus::VeteranStatusResponse do
  describe '.from' do
    subject { described_class.from(user, raw_response) }

    let(:user) { build(:user, :loa3) }
    let(:status_code) { 200 }
    let(:title38_status_code) { 'V1' }
    let(:raw_response) do
      double('Faraday::Response',
             status: status_code,
             body: {
               'profile' => {
                 'military_person' => {
                   'military_summary' => {
                     'title38_status_code' => title38_status_code
                   }
                 }
               }
             })
    end

    it 'initializes with the correct title38_status_code' do
      expect(subject.title38_status_code.title38_status_code).to eq(title38_status_code)
    end

    it 'initializes with the correct status code' do
      expect(subject.status).to eq(status_code)
    end
  end
end
