# frozen_string_literal: true

require 'rails_helper'
require File.expand_path(
  Rails.root.join(
    'spec',
    'support',
    'shared_contexts',
    'facilities_ppms.rb'
  )
)

describe Facilities::PPMS::Response do
  describe '.from_provider_locator' do
    it 'creates Providers from a ppms response' do
    end
  end
end
