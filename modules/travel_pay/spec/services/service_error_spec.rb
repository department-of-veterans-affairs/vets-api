# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::ServiceError do
  context 'raise_mapped_error' do
    # it 'throws error that has error map match' do
    #   faraday = Faraday.new("https://test.com/") do |config|
    #     config.response :raise_error
    #   end

    #   begin
    #     faraday.get("a", "b" => "c")
    #   rescue Faraday::Error => e
    #     expect do
    #       TravelPay::ServiceError.raise_mapped_error(e)
    #     end
    #       .to raise_error(ServerError, /There was a problem/i)
    #   end
    # end

    it 'disregards nil arguments' do
      expect(TravelPay::ServiceError.raise_mapped_error(nil)).to equal(nil)
      expect do
        TravelPay::ServiceError.raise_mapped_error(nil)
      end.not_to raise_error
    end
  end
end
