# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimDetailSerializer, type: :serializer do
  let(:disability_claim) { build(:disability_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  subject { serialize(disability_claim, serializer_class: DisabilityClaimDetailSerializer) }

  it 'should include id' do
    expect(data['id']).to eq(disability_claim.evss_id.to_s)
  end

  it 'should not include raw HTML' do
    expect(attributes.to_json.to_s.include?('<')).to be(false)
  end

  context 'with HTML in the description' do
    let(:disability_claim) do
      FactoryGirl.build(:disability_claim, data: {
                          'claim_tracked_items': {
                            'still_need_from_you_list': [
                              {
                                description: 'this has <h1>HTML</h1>'
                              }
                            ]
                          }
                        })
    end
    it 'strips the HTML tags' do
      expect(attributes['events_timeline'][0]['description']).to eq('this has HTML')
    end
  end

  context 'with different data and list_data' do
    let(:disability_claim) do
      FactoryGirl.build(:disability_claim, data: {
                          'waiver5103_submitted': true
                        }, list_data: {
                          'waiver5103_submitted': false
                        })
    end
    it 'should not use list_data' do
      expect(attributes['waiver_submitted']).to eq true
    end
  end

  context 'with items in vbaDocuments' do
    let(:raw_data) do
      fixture_file_name = "#{::Rails.root}/spec/fixtures/disability_claim/claim-with-documents.json"
      File.open(fixture_file_name, 'rb') do |f|
        raw_claim = f.read
        JSON.parse(raw_claim).deep_transform_keys!(&:underscore)
      end
    end
    let(:disability_claim) do
      FactoryGirl.build(:disability_claim, data: raw_data)
    end
    let(:other_documents) do
      attributes['events_timeline'].select { |obj| obj['type'] == 'other_documents_list' }
    end
    it 'should only add documents without a tracked_item_id into other_documents_list' do
      expect(other_documents.count).to eq 1
      expect(other_documents.select { |obj| !obj['tracked_item_id'].nil? }.count).to eq 0
    end
  end

  context 'with some phase dates' do
    it 'should not have a phase 1..6 event' do
      (1..6).each do |i|
        expect(attributes['events_timeline'].select { |obj| obj['type'] == "phase#{i}" }.count).to eq 0
      end
    end
    it 'should have a phase 7 event' do
      expect(attributes['events_timeline'].select { |obj| obj['type'] == 'phase7' }.count).to eq 1
    end

    let(:date_str) { Date.new(2012, 8, 10).to_json[1...-1] } # Strip quotes around date string

    it 'should have the right date for phase 7' do
      expect(attributes['events_timeline'].select { |obj| obj['type'] == 'phase7' }.first['date']).to eq date_str
    end
  end
end
