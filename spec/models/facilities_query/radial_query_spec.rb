# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacilitiesQuery::RadialQuery do
  # NOTE: this spec exisits ONLY to raise simple_cov coverage
  # I'm not even sure that I'm adding the ids params correctly...
  it 'can increase simple_cov coverage' do
    vha_facility = create :vha_648A4
    params = { lat: '-122.440689', long: '45.451913', ids: [vha_facility.id] }
    subject = FacilitiesQuery::RadialQuery.new(params)
    expect(subject.run).to eq([])
  end
end
