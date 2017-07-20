# frozen_string_literal: true
require 'rails_helper'
require 'support/preneeds_helpers'

RSpec.describe Preneeds::ApplicationForm do
  include Preneeds::Helpers

  subject { described_class.new(params) }

  let(:params) { attributes_for :application_form }
  let(:trimmed_hash) { json_symbolize(subject).except(:tracking_number, :sending_application, :sent_time) }

  it 'populates the model' do
    expect(subject.tracking_number).to be_a(String)
    expect(subject.tracking_number.length).to be <= 20
    expect(subject.sending_application).to eq('vets.gov')
    expect(subject.sent_time).to be_a(Time).and be_present
    expect(trimmed_hash).to eq(xml_dates(params))
  end

  it 'produces a message hash whose keys are ordered' do
    expect(subject.message.keys).to eq(
      [
        :applicant, :applicationStatus, :claimant, :currentlyBuriedPersons,
        :hasAttachments, :hasCurrentlyBuried, :sendingApplication, :sendingCode,
        :sentTime, :trackingNumber, :veteran
      ]
    )
  end
end
