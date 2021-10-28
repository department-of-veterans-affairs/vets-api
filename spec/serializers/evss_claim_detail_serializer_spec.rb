# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimDetailSerializer do
  subject { serialize(evss_claim, serializer_class: EVSSClaimDetailSerializer) }

  let(:evss_claim) { build(:evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes id' do
    expect(data['id']).to eq(evss_claim.evss_id.to_s)
  end

  it 'does not include raw HTML' do
    expect(attributes.to_json.to_s.include?('<')).to be(false)
  end

  context 'with HTML in the description' do
    let(:evss_claim) do
      FactoryBot.build(:evss_claim, data: {
                         claim_tracked_items: {
                           still_need_from_you_list: [
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

  context 'with HTML in the VA representative field' do
    let(:evss_claim) do
      FactoryBot.build(:evss_claim, data: { poa: '&lt;VATreatmentCenter&gt;' })
    end

    it 'strips the HTML tags' do
      expect(attributes['va_representative']).to eq('VATreatmentCenter')
    end
  end

  context 'with different data and list_data' do
    let(:evss_claim) do
      FactoryBot.build(:evss_claim, data: {
                         waiver5103_submitted: true
                       }, list_data: {
                         waiver5103_submitted: false
                       })
    end

    it 'does not use list_data' do
      expect(attributes['waiver_submitted']).to eq true
    end
  end

  context 'with items in vbaDocuments' do
    let(:raw_data) do
      fixture_file_name = "#{::Rails.root}/spec/fixtures/evss_claim/claim-with-documents.json"
      File.open(fixture_file_name, 'rb') do |f|
        raw_claim = f.read
        JSON.parse(raw_claim).deep_transform_keys!(&:underscore)
      end
    end
    let(:evss_claim) do
      FactoryBot.build(:evss_claim, data: raw_data)
    end
    let(:other_documents) do
      attributes['events_timeline'].select { |obj| obj['type'] == 'other_documents_list' }
    end

    it 'onlies add documents without a tracked_item_id into other_documents_list' do
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
