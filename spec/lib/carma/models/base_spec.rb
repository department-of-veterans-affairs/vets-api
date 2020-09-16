# frozen_string_literal: true

require 'rails_helper'
require 'carma/models/base'

RSpec.describe CARMA::Models::Base, type: :model do
  describe '::request_payload_key' do
    context 'will set the class variable :request_payload_keys to the provided args' do
      it 'requires an arg' do
        class TestOne < CARMA::Models::Base
        end

        expect { TestOne.request_payload_key }.to raise_error(
          ArgumentError,
          'wrong number of arguments (given 0, expected 1+)'
        )
      end

      it 'sets the arg to :request_payload_keys' do
        class TestTwo < CARMA::Models::Base
          request_payload_key :my_attr
        end

        expect(TestTwo.request_payload_keys).to eq([:my_attr])
      end

      it 'can set multiple args to :request_payload_keys' do
        class TestThree < CARMA::Models::Base
          request_payload_key :my_attr, :my_other_attr
        end

        expect(TestThree.request_payload_keys).to eq(%i[my_attr my_other_attr])
      end

      it 'can be called multiple times' do
        class TestFour < CARMA::Models::Base
          request_payload_key :one, :two
          request_payload_key :three
        end

        expect(TestFour.request_payload_keys).to eq(%i[one two three])
      end
    end
  end

  describe '#to_request_payload' do
    it 'parses the model to a hash containing only the attributes listed in request_payload_key, with camelCase keys' do
      class PersonOne < CARMA::Models::Base
        attr_accessor :name, :is_veteran, :age, :state

        request_payload_key :name, :is_veteran, :age

        def initialize
          @name = 'Kevin'
          @is_veteran = true
          @age = 90
          @state = 'FL'
        end
      end

      expect(PersonOne.new.to_request_payload).to eq(
        {
          'name' => 'Kevin',
          'isVeteran' => true,
          'age' => 90
        }
      )
    end

    it 'will recursively parse nested models inheriting the same Base class' do
      class PersonTwo < CARMA::Models::Base
        attr_accessor :name, :is_veteran, :age, :state, :favorites

        request_payload_key :name, :age, :favorites

        def initialize
          @name = 'Kevin'
          @is_veteran = true
          @age = 90
          @state = 'FL'
          @favorites = Favorites.new
        end

        class Favorites < CARMA::Models::Base
          attr_accessor :restaurant, :color

          request_payload_key :color

          def initialize
            @restaurant = Restaurant.new
            @color = Color.new
          end

          class Color < CARMA::Models::Base
            attr_accessor :color_type, :color_code

            request_payload_key :color_type

            def initialize
              @color_type = 'red'
              @color_code = 1
            end
          end

          class Restaurant < CARMA::Models::Base
            attr_accessor :name, :address_zip

            request_payload_key :address_zip

            def initialize
              @name = 'Pizza Place'
              @address_zip = 12_345
            end
          end
        end
      end

      expect(PersonTwo.new.to_request_payload).to eq(
        {
          'name' => 'Kevin',
          'favorites' => {
            'color' => {
              'colorType' => 'red'
            }
          },
          'age' => 90
        }
      )
    end
  end

  describe '::after_to_request_payload' do
    it 'will call the provided method after running #to_request_payload, and return its result' do
      class PersonThree < CARMA::Models::Base
        attr_accessor :name, :is_veteran, :age, :state, :favorites

        request_payload_key :name, :age, :favorites
        after_to_request_payload :mutate_result

        def initialize
          @name = 'Kevin'
          @is_veteran = true
          @age = 90
          @state = 'FL'
          @favorites = Favorites.new
        end

        def mutate_result(data)
          data['age'] = data['age'].to_s
          data
        end

        class Favorites < CARMA::Models::Base
          attr_accessor :restaurant, :color

          request_payload_key :color

          def initialize
            @restaurant = Restaurant.new
            @color = Color.new
          end

          class Color < CARMA::Models::Base
            attr_accessor :color_type, :color_code

            request_payload_key :color_type

            def initialize
              @color_type = 'red'
              @color_code = 1
            end
          end

          class Restaurant < CARMA::Models::Base
            attr_accessor :name, :address_zip

            request_payload_key :address_zip

            def initialize
              @name = 'Pizza Place'
              @address_zip = 12_345
            end
          end
        end
      end

      expect(PersonThree.new.to_request_payload).to eq(
        {
          'name' => 'Kevin',
          'favorites' => {
            'color' => {
              'colorType' => 'red'
            }
          },
          'age' => '90'
        }
      )
    end
  end
end
