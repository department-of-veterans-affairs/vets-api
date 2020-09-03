# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Concerns::Defaultable do
  describe 'set_defaults' do
    let(:user) { create :user, :loa3 }
    let(:email) { Vet360::Models::Email.new }
    let(:default_attrs) { %i[effective_start_date source_date vet360_id].freeze }

    it 'sets the default attributes', :aggregate_failures do
      default_attrs.each do |attr|
        expect(email.send(attr).present?).to eq false
      end

      email.set_defaults user

      default_attrs.each do |attr|
        expect(email.send(attr).present?).to eq true
      end
    end
  end
end
