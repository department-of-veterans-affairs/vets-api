# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/service/base'

require_relative 'shared/service'

RSpec.describe DigitalFormsApi::Service::Base do
  let(:service) { described_class.new }

  it_behaves_like 'a DigitalFormsApi::Service class'
end
