# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/serializers/claims_api/concerns/events_timeline'

class DummyEventsSerializer
  include JSONAPI::Serializer
  include ClaimsApi::Concerns::EventsTimeline

  def self.object_data(object)
    object.data
  end
end

describe ClaimsApi::Concerns::EventsTimeline, type: :concern do
  subject { serialize(evss_claim, serializer_class: DummyEventsSerializer) }

  let(:evss_claim) { build_stubbed(:evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:claim_data) { evss_claim.data }

  it 'includes events_timeline' do
    expect(attributes['events_timeline']).to be_an(Array)
  end

  context 'with HTML in the description' do
    let(:claim_data) do
      {
        claim_tracked_items: {
          still_need_from_you_list: [
            {
              description: 'this has <h1>HTML</h1>'
            }
          ]
        }
      }
    end
    let(:evss_claim) { build(:evss_claim, data: claim_data) }

    it 'strips the HTML tags' do
      expect(attributes['events_timeline'][0]['description']).to eq('this has HTML')
    end
  end

  context 'with items in vbaDocuments' do
    let(:raw_data) do
      fixture_file_name = Rails.root.join(
        *'/spec/fixtures/evss_claim/claim-with-documents.json'.split('/')
      ).to_s
      File.open(fixture_file_name, 'rb') do |f|
        raw_claim = f.read
        JSON.parse(raw_claim).deep_transform_keys!(&:underscore)
      end
    end
    let(:evss_claim) { build(:evss_claim, data: raw_data) }

    it 'only adds documents without a tracked_item_id into other_documents_list' do
      other_documents = attributes['events_timeline'].select { |obj| obj['type'] == 'other_documents_list' }
      expect(other_documents.count).to eq 1
      expect(other_documents.reject { |obj| obj['tracked_item_id'].nil? }.count).to eq 0
    end

    it 'uses the upload date for the tracked item' do
      tracked_item = attributes['events_timeline'].detect { |event| event['tracked_item_id'] == 211_684 }
      expect(tracked_item['date']).to eq('2016-11-04')
    end
  end

  context 'with some phase dates' do
    let(:date_str) { Date.new(2012, 8, 10).to_json[1...-1] }

    it 'does not have a phase 1..6 event' do
      (1..6).each do |i|
        expect(attributes['events_timeline'].select { |obj| obj['type'] == "phase#{i}" }.count).to eq 0
      end
    end

    it 'has a phase 7 event' do
      expect(attributes['events_timeline'].select { |obj| obj['type'] == 'phase7' }.count).to eq 1
    end

    it 'has the right date for phase 7' do
      expect(attributes['events_timeline'].select { |obj| obj['type'] == 'phase7' }.first['date']).to eq date_str
    end
  end
end
