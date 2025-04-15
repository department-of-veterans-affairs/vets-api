# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::Submission, type: :model do
  it { is_expected.to validate_presence_of :form_id }
end
