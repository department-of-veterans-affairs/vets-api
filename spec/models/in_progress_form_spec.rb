# frozen_string_literal: true
require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe InProgressForm, type: :model do
  describe 'form encryption' do
    it { encrypts(:form_data) }
  end
end
