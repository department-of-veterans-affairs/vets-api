# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::MetadataValidator do
  describe 'metadata is valid' do
    it 'returns unmodified metadata' do
      metadata = {
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '444444444',
        'zipCode' => '12345',
        'source' => 'VA Platform Digital Forms',
        'docType' => '21-0845',
        'businessLine' => 'CMP'
      }

      validated_metadata = SimpleFormsApi::MetadataValidator.validate(metadata)

      expect(validated_metadata).to eq(metadata)
    end
  end

  describe 'veteran first name is malformed' do
    describe 'missing' do
      it 'raises an exception' do
        metadata = {
          'veteranFirstName' => nil,
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect { SimpleFormsApi::MetadataValidator.validate(metadata) }.to raise_error(ArgumentError, 'veteran first name is missing')
      end
    end

    describe 'non-string' do
      it 'returns metadata with stringified veteran first name' do
        metadata = {
          'veteranFirstName' => 12,
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect { SimpleFormsApi::MetadataValidator.validate(metadata) }.to raise_error(ArgumentError, 'veteran first name is not a string')
      end
    end

    describe 'too long' do
      it 'returns metadata with first 50 characters of veteran first name' do
        metadata = {
          'veteranFirstName' => 'Wolfeschlegelsteinhausenbergerdorffwelchevoralternwarengewissenhaftschaferswessenschafewarenwohlgepflegeundsorg \
            faltigkeitbeschutzenvonangreifendurchihrraubgierigfeindewelchevoralternzwolftausendjahresvorandieerscheinenvanderersteerdemenschderraum \
            schiffgebrauchlichtalsseinursprungvonkraftgestartseinlangefahrthinzwischensternartigraumaufdersuchenachdiesternwelchegehabtbewohnbar \
            planetenkreisedrehensichundwohinderneurassevonverstandigmenschlichkeitkonntefortpflanzenundsicherfreuenanlebenslanglichfreudeundruhemit \
            nichteinfurchtvorangreifenvonandererintelligentgeschopfsvonhinzwischensternartigraum',
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }
        expected_metadata = {
          'veteranFirstName' => 'Wolfeschlegelsteinhausenbergerdorffwelchevoraltern',
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        validated_metadata = SimpleFormsApi::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end
    end

    describe 'contains disallowed characters' do
      it 'returns metadata with disallowed characters of veteran first name stripped' do
        metadata = {
          'veteranFirstName' => '2John~! - Jo/hn?\\',
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }
        expected_metadata = {
          'veteranFirstName' => 'John - Jo/hn',
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        validated_metadata = SimpleFormsApi::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end
    end
  end
end
