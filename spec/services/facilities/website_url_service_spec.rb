# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::WebsiteUrlService do
  it 'provides the url when it knows about a station id' do
    service = Facilities::WebsiteUrlService.new
    url = service.find_for_station('0231V')
    expect(url).to eq('http://www.beckley.va.gov/')
  end

  it 'provides an empty string when it does not know about a station id' do
    service = Facilities::WebsiteUrlService.new
    url = service.find_for_station('fAkE1D')
    expect(url).to eq('')
  end
end

