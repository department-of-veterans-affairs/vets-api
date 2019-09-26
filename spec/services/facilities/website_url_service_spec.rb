# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::WebsiteUrlService do
  it 'provides the url when it knows about a station id and facility type' do
    service = Facilities::WebsiteUrlService.new
    url = service.find_for_station('0231V', 'va_health_facility')
    expect(url).to eq('http://www.beckley.va.gov/')
  end

  it 'provides the url for the correct type of facility' do
    service = Facilities::WebsiteUrlService.new
    health_url = service.find_for_station('402', 'va_health_facility')
    benefits_url = service.find_for_station('402', 'va_benefits_facility')
    expect(health_url).to eq('http://www.maine.va.gov/')
    expect(benefits_url).to eq('http://www.benefits.va.gov/togus/')
  end

  it 'provides an nil when it does not know about a station id' do
    service = Facilities::WebsiteUrlService.new
    url = service.find_for_station('fAkE1D', 'va_health_facility')
    expect(url).to be_nil
  end

  it 'handles lowercase in StationNum column' do
    service = Facilities::WebsiteUrlService.new
    url = service.find_for_station('589GF', 'va_health_facility')
    expect(url).to eq('http://www.columbiamo.va.gov/locations/Fort_Leonard_Wood.asp')
  end
end
