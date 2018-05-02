# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::Base do
  describe '#default_attrs_present?' do
    it "returns true if the model instance's has all of the DEFAULT_ATTRS" do
      email = build :email

      expect(email.default_attrs_present?).to eq true
    end

    it "returns false if the model instance's does not have all of the DEFAULT_ATTRS" do
      vet360_message = build :vet360_message

      expect(vet360_message.default_attrs_present?).to eq false
    end
  end

  describe '.with_defaults' do
    let(:user) { create :user, :loa3 }

    context 'for model instances that have the default attributes' do
      let(:email) { Vet360::Models::Email.with_defaults(user, {}) }

      it 'creates an instance of the associated class' do
        expect(email.class).to eq Vet360::Models::Email
      end

      it 'sets the default attributes', :aggregate_failures do
        Vet360::Models::Base::DEFAULT_ATTRS.each do |attr|
          expect(email.send(attr).present?).to eq true
        end
      end
    end

    context 'for model instances that do not have the default attributes' do
      it 'returns nil' do
        message = Vet360::Models::Message.with_defaults(user, {})

        expect(message).to be_nil
      end
    end
  end
end
