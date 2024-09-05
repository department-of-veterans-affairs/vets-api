# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::Form2122Data, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it { expect(subject).to validate_presence_of(:organization_name) }
  end
end
