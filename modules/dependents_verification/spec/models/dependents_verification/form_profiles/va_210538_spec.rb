# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsVerification::FormProfiles::VA210538, type: :model do
  subject { described_class.new(form_id:, user:) }

  let(:user) { build(:user, :loa3) }
  let(:form_id) { '21-0538' }

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
    allow(FormProfile).to receive(:prefill_enabled_forms).and_return([form_id])
  end

  describe '#metadata' do
    it 'returns correct metadata' do
      expect(subject.metadata).to eq(
        version: 0,
        prefill: true,
        returnUrl: '/veteran-information'
      )

      subject.metadata
    end
  end

  describe '#prefill' do
    it 'initializes identity and contact information' do
      expect(subject.prefill).to match({
        form_data: {
          "veteranInformation" => { "fullName" => { "first" => "Abraham", "last" => "Lincoln", "suffix" => "Jr." },
          "ssn" => "796111863", "birthDate" => "1809-02-12" },
          "veteranContactInformation" => {
            "veteranAddress" => {
              "street" => "140 Rock Creek Rd",
              "city" => "Washington",
              "state" => "DC",
              "country" => "USA",
              "postalCode" => "20011"
            },
            "mobilePhone" => "3035551234",
            "homePhone" => "3035551234",
            "usPhone" => "3035551234",
            "emailAddress" => be_a(String)
          }
        },
        metadata: { version: 0, prefill: true, returnUrl: "/veteran-information" } })
    end
  end
end
