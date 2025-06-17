# frozen_string_literal: true

require 'rails_helper'
require 'bb/generate_report_request_form'
require 'bb/client'

describe BB::GenerateReportRequestForm do
  subject { described_class.new(bb_client, attributes) }

  let(:eligible_data_classes) do
    BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES
  end

  let(:bb_client) do
    VCR.use_cassette 'bb_client/session' do
      client = BB::Client.new(session: { user_id: '12210827' })
      client.authenticate
      client
    end
  end

  let(:time_before) { Time.parse('2000-01-01T12:00:00-05:00').utc }
  let(:time_after)  { Time.parse('2016-01-01T12:00:00-05:00').utc }

  let(:attributes) { {} }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
    allow(subject).to receive(:eligible_data_classes).and_return(eligible_data_classes)
  end

  context 'with null attributes' do
    it 'responds to params' do
      expect(subject.params)
        .to eq(from_date: nil, to_date: nil, data_classes: [])
    end

    it 'returns valid false with errors' do
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages)
        .to eq([
                 'From date is not a date',
                 'To date is not a date',
                 "Data classes can't be blank"
               ])
    end
  end

  context 'with invalid dates' do
    let(:attributes) do
      { from_date: time_after.iso8601, to_date: time_before.iso8601, data_classes: eligible_data_classes }
    end

    it 'responds to params' do
      expect(subject.params)
        .to eq(from_date: time_after.httpdate, to_date: time_before.httpdate, data_classes: eligible_data_classes)
    end

    # This spec can be added again in the future if desired, but for now leave as MHV error
    it 'returns valid false with errors', skip: 'MHV error' do
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages)
        .to eq(['From date must be before to date'])
    end
  end

  context 'with invalid data_classes' do
    let(:invalid_data_classes) { %w[blah blahblah] }
    let(:attributes) do
      { from_date: time_before.iso8601, to_date: time_after.iso8601, data_classes: invalid_data_classes }
    end

    # TODO: See: https://github.com/department-of-veterans-affairs/vets.gov-team/issues/3777
    it 'responds to params' do
      expect(subject.params)
        .to eq(from_date: time_before.httpdate, to_date: time_after.httpdate, data_classes: []) # invalid_data_classes)
    end

    # TODO: See: https://github.com/department-of-veterans-affairs/vets.gov-team/issues/3777
    it 'returns valid false' do
      expect(subject).to be_valid # be_falsey
      expect(subject.errors.full_messages)
        .to be_empty # eq(['Invalid data classes: blah, blahblah'])
    end

    # TODO: remove this temporary behavior
    # TODO: See: https://github.com/department-of-veterans-affairs/vets.gov-team/issues/3777
    it 'intersects out invalid classes' do
      expect(subject.overridden_data_classes).to be_empty
    end
  end

  context 'with valid attributes' do
    let(:attributes) do
      { from_date: time_before.iso8601, to_date: time_after.iso8601, data_classes: eligible_data_classes }
    end

    it 'responds to params' do
      expect(subject.params)
        .to eq(from_date: time_before.httpdate, to_date: time_after.httpdate, data_classes: eligible_data_classes)
    end

    it 'returns valid true' do
      expect(subject).to be_valid
    end
  end
end
