# frozen_string_literal: true
require 'rails_helper'
require_dependency 'common/models/collection'
# FIXME: Refactor this to be more generic, less dependent on Prescription Fixture
require_dependency 'rx/parser'

describe Common::Collection do
  let(:klass) { Prescription }
  let(:original_camel_cased_json) { File.read('spec/support/fixtures/get_active_rxs.json') }
  let(:parsed_json_object) { Rx::Parser.new(JSON.parse(original_camel_cased_json)).parse! }
  let(:snake_cased_attributes) do
    %w(refill_status refill_submit_date refill_date refill_remaining facility_name
       is_refillable is_trackable prescription_id ordered_date quantity expiration_date
       prescription_number prescription_name dispensed_date station_number)
  end

  subject { described_class.new(klass, parsed_json_object) }

  it 'returns a JSON string' do
    expect(subject.to_json).to be_a(String)
  end

  it 'returns a JSON string whose keys and nested keys are snake cased' do
    json = JSON.parse(subject.to_json)
    expect(json.first.keys).to contain_exactly(*snake_cased_attributes)
  end

  it 'can return members' do
    expect(subject.members.first).to be_a(Prescription)
  end

  it 'can return members' do
    expect(subject.members).to be_an(Array)
  end

  it 'can return metadata' do
    expect(subject.metadata).to include(failed_station_list: '', updated_at: 'Thu, 26 May 2016 13:05:43 EDT')
  end

  context 'complex sort' do
    it 'can sort a collection in reverse' do
      collection = subject.sort('-prescription_id')
      expect(collection.map(&:prescription_id))
        .to eq([1_435_530, 1_435_528, 1_435_527, 1_435_526, 1_435_525, 1_435_524])
      expect(collection.metadata[:sort]).to eq('prescription_id' => 'DESC')
    end

    it 'can sort a collection by multiple fields' do
      collection = subject.sort('facility_name,-prescription_id')
      expect(collection.map(&:prescription_id))
        .to eq([1_435_526, 1_435_525, 1_435_524, 1_435_530, 1_435_528, 1_435_527])
      expect(collection.metadata[:sort]).to eq('facility_name' => 'ASC', 'prescription_id' => 'DESC')
    end
  end

  context 'find_by, sort, and paginate' do
    let(:filtered_collection)  { subject.find_by(:prescription_id, 1_435_525) }
    let(:sorted_collection)    { subject.sort('prescription_id') }
    let(:paginated_collection) { subject.paginate(page: 1, per_page: 2) }
    let(:all_three) do
      subject.find_by(:refill_status, 'active').sort('-refill_date').paginate(page: 1, per_page: 3)
    end

    it 'can filter a collection' do
      expect(filtered_collection).to be_a(Common::Collection)
      expect(filtered_collection.data.size).to eq(1)
      expect(filtered_collection.metadata)
        .to eq(updated_at: 'Thu, 26 May 2016 13:05:43 EDT',
               failed_station_list: '',
               filter: { for: 'prescription_id', having: 1_435_525 })
    end

    it 'can sort a collection' do
      expect(sorted_collection).to be_a(Common::Collection)
      expect(sorted_collection.data.map(&:prescription_id))
        .to eq([1_435_524, 1_435_525, 1_435_526, 1_435_527, 1_435_528, 1_435_530])
      expect(sorted_collection.metadata)
        .to eq(updated_at: 'Thu, 26 May 2016 13:05:43 EDT',
               failed_station_list: '',
               sort: { 'prescription_id' => 'ASC' })
    end

    it 'can paginate a collection' do
      expect(paginated_collection).to be_a(Common::Collection)
      expect(paginated_collection.data.size).to eq(2)
      expect(paginated_collection.metadata)
        .to eq(updated_at: 'Thu, 26 May 2016 13:05:43 EDT',
               failed_station_list: '',
               pagination: { current_page: 1, per_page: 2, total_pages: 3, total_entries: 6 })
    end

    it 'can do all three' do
      expect(all_three).to be_a(Common::Collection)
      expect(all_three.data.size).to eq(3)
      expect(all_three.metadata)
        .to eq(updated_at: 'Thu, 26 May 2016 13:05:43 EDT',
               failed_station_list: '',
               filter: { for: 'refill_status', having: 'active' },
               sort: { 'refill_date' => 'DESC' },
               pagination: { current_page: 1, per_page: 3, total_pages: 2, total_entries: 6 })
    end
  end
end
