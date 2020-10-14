# frozen_string_literal: true

require 'rails_helper'
require 'facilities/ppms/do_not_encoder'

RSpec.describe Facilities::PPMS::DoNotEncoder, team: :facilities do
  it 'does not encode spaces to +' do
    params = {
      key: :value,
      address: 'something something darkside'
    }
    expect(
      Facilities::PPMS::DoNotEncoder.encode(params)
    ).to eql('key=value&address=something something darkside')
  end
end
