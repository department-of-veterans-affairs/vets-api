# frozen_string_literal: true

require 'rails_helper'

describe VIC::Configuration do
  describe '.get_instance_url' do
    context 'with an env of uat' do
      it 'should return the right url' do
        expect(described_class.get_sf_instance_url('uat')).to eq(
          'https://va--UAT.cs32.my.salesforce.com'
        )
      end
    end

    context 'with an env of dev' do
      it 'should return the right url' do
        expect(described_class.get_sf_instance_url('dev')).to eq(
          'https://va--VICDEV.cs33.my.salesforce.com'
        )
      end
    end
  end
end
