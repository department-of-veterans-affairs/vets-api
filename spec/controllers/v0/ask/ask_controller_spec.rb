# frozen_string_literal: true

RSpec.describe V0::Ask::AskController, type: :controller do
  describe '#create' do
    context 'when user submits form with valid data - and the toggle is on' do
      #set the toggle to be true


      it "should call the CRM gateway" do
      # confirm the feature toggle is off
      # throw json error message? 404? feature toggle is turned off? logging?
      end

      it "should send Http status code 200" do
        end

    end

    context 'when user submits form with invalid data' do
      it "should throw Http status code 500 with error message" do

      end

      it "should log error messages in sentry" do

      end
    end

    end
  end
