# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacilitiesQuery::IdsQuery do
  # NOTE: this spec exisits ONLY to raise simple_cov coverage
  # I'm not even sure that I'm adding the ids params correctly...
  it 'can increase simple_cov coverage' do
    vha_facility = create :vha_648A4
    params = { ids: "vha_#{vha_facility.id}" }
    subject = FacilitiesQuery::IdsQuery.new(params)
    expect(subject.run).to eq([vha_facility])
  end
end
