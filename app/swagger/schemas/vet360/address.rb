# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class Address
        include Swagger::Blocks

        swagger_schema :PostVet360DomesticAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            city
            country
            state_abbr
            zip_code
          ]
          property :address_line1, type: :string, example: '1493 Martin Luther King Rd'
          property :address_line2, type: :string
          property :address_line3, type: :string
          property :address_pou, type: :string, enum: %w[
            RESIDENCE/CHOICE
            CORRESPONDENCE
          ], example: 'RESIDENCE/CHOICE'
          property :address_type, type: :string, enum: [
            'domestic',
            'international',
            'military overseas'
          ], example: 'domestic'
          property :city, type: :string, example: 'Fulton'
          property :country, type: :string, example: 'USA'
          property :state_abbr, type: :string, example: 'MS'
          property :zip_code, type: :string, example: '38843'
        end

        swagger_schema :PutVet360DomesticAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            city
            country
            id
            state_abbr
            zip_code
          ]
          property :id, type: :integer, example: 1
          property :address_line1, type: :string, example: '1493 Martin Luther King Rd'
          property :address_line2, type: :string
          property :address_line3, type: :string
          property :address_pou, type: :string, enum: %w[
            RESIDENCE/CHOICE
            CORRESPONDENCE
          ], example: 'RESIDENCE/CHOICE'
          property :address_type, type: :string, enum: [
            'domestic',
            'international',
            'military overseas'
          ], example: 'domestic'
          property :city, type: :string, example: 'Fulton'
          property :country, type: :string, example: 'USA'
          property :state_abbr, type: :string, example: 'MS'
          property :zip_code, type: :string, example: '38843'
        end

        swagger_schema :PostVet360InternationalAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            international_postal_code
            city
            country
          ]
          property :address_line1, type: :string, example: '1493 Martin Luther King Rd'
          property :address_line2, type: :string
          property :address_line3, type: :string
          property :address_pou, type: :string, enum: %w[
            RESIDENCE/CHOICE
            CORRESPONDENCE
          ], example: 'RESIDENCE/CHOICE'
          property :address_type, type: :string, enum: [
            'domestic',
            'international',
            'military overseas'
          ], example: 'international'
          property :country, type: :string, example: 'USA'
          property :international_postal_code, type: :string, example: '12345'
        end

        swagger_schema :PutVet360InternationalAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            id
            international_postal_code
            city
            country
          ]
          property :id, type: :integer, example: 1
          property :address_line1, type: :string, example: '1493 Martin Luther King Rd'
          property :address_line2, type: :string
          property :address_line3, type: :string
          property :address_pou, type: :string, enum: %w[
            RESIDENCE/CHOICE
            CORRESPONDENCE
          ], example: 'RESIDENCE/CHOICE'
          property :address_type, type: :string, enum: [
            'domestic',
            'international',
            'military overseas'
          ], example: 'international'
          property :country, type: :string, example: 'USA'
          property :international_postal_code, type: :string, example: '12345'
        end

        swagger_schema :PostVet360MilitaryOverseasAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            city
            country
            state_abbr
            zip_code
          ]
          property :address_line1, type: :string, example: '1493 Martin Luther King Rd'
          property :address_line2, type: :string
          property :address_line3, type: :string
          property :address_pou, type: :string, enum: %w[
            RESIDENCE/CHOICE
            CORRESPONDENCE
          ], example: 'RESIDENCE/CHOICE'
          property :address_type, type: :string, enum: [
            'domestic',
            'international',
            'military overseas'
          ], example: 'military overseas'
          property :city, type: :string, example: 'Fulton'
          property :country, type: :string, example: 'USA'
          property :state_abbr, type: :string, example: 'MS'
          property :zip_code, type: :string, example: '38843'
        end

        swagger_schema :PutVet360MilitaryOverseasAddress do
          key :required, %i[
            address_line1
            address_pou
            address_type
            city
            country
            id
            state_abbr
            zip_code
          ]
          property :id, type: :integer, example: 1
          property :address_line1, type: :string, example: '1493 Martin Luther King Rd'
          property :address_line2, type: :string
          property :address_line3, type: :string
          property :address_pou, type: :string, enum: %w[
            RESIDENCE/CHOICE
            CORRESPONDENCE
          ], example: 'RESIDENCE/CHOICE'
          property :address_type, type: :string, enum: [
            'domestic',
            'international',
            'military overseas'
          ], example: 'military overseas'
          property :city, type: :string, example: 'Fulton'
          property :country, type: :string, example: 'USA'
          property :state_abbr, type: :string, example: 'MS'
          property :zip_code, type: :string, example: '38843'
        end
      end
    end
  end
end
