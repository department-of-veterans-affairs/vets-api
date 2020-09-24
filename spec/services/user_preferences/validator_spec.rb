# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserPreferences::Validator do
  let(:user) { build(:user, :accountable) }
  let(:account) { user.account }
  let(:preference_1) { create :preference }
  let(:preference_2) { create :preference }
  let(:choice_1) { create :preference_choice, preference: preference_1 }
  let(:choice_2) { create :preference_choice, preference: preference_1 }
  let(:choice_3) { create :preference_choice, preference: preference_2 }
  let(:choice_4) { create :preference_choice, preference: preference_2 }

  describe '#of_presence!' do
    context 'when initialized with valid requested_user_preferences' do
      let(:requested_user_preferences) do
        [
          {
            preference: {
              code: preference_1.code
            },
            user_preferences: [
              { code: choice_1.code },
              { code: choice_2.code }
            ]
          },
          {
            preference: {
              code: preference_2.code
            },
            user_preferences: [
              { code: choice_3.code },
              { code: choice_4.code }
            ]
          }
        ].as_json
      end

      it 'does not raise any exceptions' do
        expect { UserPreferences::Validator.new(requested_user_preferences).of_presence! }.not_to raise_error
      end

      it 'returns the original initialized requested_user_preferences' do
        response = UserPreferences::Validator.new(requested_user_preferences).of_presence!

        expect(response).to eq requested_user_preferences
      end
    end

    context 'when initialized without a :preference key' do
      let(:empty_preference_request) do
        [
          {
            user_preferences: [
              { code: choice_1.code },
              { code: choice_2.code }
            ]
          },
          {
            preference: {
              code: preference_2.code
            },
            user_preferences: [
              { code: choice_3.code },
              { code: choice_4.code }
            ]
          }
        ].as_json
      end

      it 'raises an exception', :aggregate_failures do
        expect { UserPreferences::Validator.new(empty_preference_request).of_presence! }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ParameterMissing)
          expect(error.status_code).to eq 400
          expect(error.errors.first.title).to eq 'Missing parameter'
          expect(error.errors.first.detail).to include 'preference#code'
        end
      end
    end

    context 'when initialized with a preference that does not contain a :code' do
      let(:empty_preference_request) do
        [
          {
            preference: {
              title: preference_1.code
            },
            user_preferences: [
              { code: choice_1.code },
              { code: choice_2.code }
            ]
          },
          {
            preference: {
              code: preference_2.code
            },
            user_preferences: [
              { code: choice_3.code },
              { code: choice_4.code }
            ]
          }
        ].as_json
      end

      it 'raises an exception', :aggregate_failures do
        expect { UserPreferences::Validator.new(empty_preference_request).of_presence! }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ParameterMissing)
          expect(error.status_code).to eq 400
          expect(error.errors.first.title).to eq 'Missing parameter'
          expect(error.errors.first.detail).to include 'preference#code'
        end
      end
    end

    context 'when initialized without a :user_preferences key' do
      let(:empty_user_preference_request) do
        [
          {
            preference: {
              code: preference_1.code
            }
          },
          {
            preference: {
              code: preference_2.code
            },
            user_preferences: [
              { code: choice_3.code },
              { code: choice_4.code }
            ]
          }
        ].as_json
      end

      it 'raises an exception', :aggregate_failures do
        expect { UserPreferences::Validator.new(empty_user_preference_request).of_presence! }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ParameterMissing)
          expect(error.status_code).to eq 400
          expect(error.errors.first.title).to eq 'Missing parameter'
          expect(error.errors.first.detail).to include 'user_preferences'
        end
      end
    end

    context 'when initialized with an empty a user_preferences array' do
      let(:empty_user_preference_request) do
        [
          {
            preference: {
              code: preference_1.code
            },
            user_preferences: []
          },
          {
            preference: {
              code: preference_2.code
            },
            user_preferences: [
              { code: choice_3.code },
              { code: choice_4.code }
            ]
          }
        ].as_json
      end

      it 'raises an exception', :aggregate_failures do
        expect { UserPreferences::Validator.new(empty_user_preference_request).of_presence! }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ParameterMissing)
          expect(error.status_code).to eq 400
          expect(error.errors.first.title).to eq 'Missing parameter'
          expect(error.errors.first.detail).to include 'user_preferences'
        end
      end
    end

    context 'when initialized with a user_preference that does not contain a :code' do
      let(:empty_user_preference_request) do
        [
          {
            preference: {
              code: preference_1.code
            },
            user_preferences: [{ title: choice_1.code }]
          },
          {
            preference: {
              code: preference_2.code
            },
            user_preferences: [
              { code: choice_3.code },
              { code: choice_4.code }
            ]
          }
        ].as_json
      end

      it 'raises an exception', :aggregate_failures do
        expect { UserPreferences::Validator.new(empty_user_preference_request).of_presence! }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ParameterMissing)
          expect(error.status_code).to eq 400
          expect(error.errors.first.title).to eq 'Missing parameter'
          expect(error.errors.first.detail).to include 'user_preference#code'
        end
      end
    end
  end
end
