# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::BurialForm do
  subject { described_class.new(params) }

  let(:params) { attributes_for(:burial_form) }

  describe 'when setting defaults' do
    it 'generates a tracking_number' do
      expect(subject.tracking_number).not_to be_blank
    end

    it 'generates sent_time' do
      expect(subject.sent_time).not_to be_blank
    end

    it 'provides vets.gov as the sending_application' do
      params.delete(:sending_application)
      expect(subject.sending_application).to eq('vets.gov')
    end
  end

  describe 'when converting to eoas' do
    it 'produces an ordered hash' do
      expect(subject.as_eoas.keys).to eq(
        %i[
          applicant applicationStatus attachments claimant currentlyBuriedPersons
          hasAttachments hasCurrentlyBuried sendingApplication sendingCode
          sentTime trackingNumber veteran
        ]
      )
    end

    it 'removes currentlyBuriedPersons if blank' do
      params[:currently_buried_persons] = []
      expect(subject.as_eoas.keys).not_to include(:currentlyBuriedPersons)
    end
  end

  describe 'when converting to json' do
    it 'converts its attributes from snakecase to camelcase' do
      camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      expect(camelcased).to eq(subject.as_json.except('sentTime', 'trackingNumber', 'hasAttachments'))
    end
  end

  describe 'when validating' do
    it 'compares a form against the schema' do
      schema = VetsJsonSchema::SCHEMAS['40-10007']
      expect(described_class.validate(schema, described_class.new(params))).to be_empty
    end
  end
end
