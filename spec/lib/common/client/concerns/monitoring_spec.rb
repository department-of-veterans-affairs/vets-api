# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Common::Client::Monitoring, type: :model do
  let (:service) { }

  describe '.with_monitoring' do
    it 'increments total' do
    end

    it 'increments failures' do
    end

    it 'increments by zero if that hasnt happened since app deploy' do
    end
  end
end
