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
      it 'raises a missing exception' do
        metadata = {
          'veteranFirstName' => nil,
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect do
          SimpleFormsApi::MetadataValidator.validate(metadata)
        end.to raise_error(ArgumentError, 'veteran first name is missing')
      end
    end

    describe 'non-string' do
      it 'raises a non-string exception' do
        metadata = {
          'veteranFirstName' => 12,
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect do
          SimpleFormsApi::MetadataValidator.validate(metadata)
        end.to raise_error(ArgumentError,
                         'veteran first name is not a string')
      end
    end

    describe 'too long' do
      it 'returns metadata with first 50 characters of veteran first name' do
        metadata = {
          'veteranFirstName' => 'Wolfeschlegelsteinhausenbergerdorffwelchevoralternwarengewissenhaftschaferswessenschafe
            warenwohlgepflegeundsorgfaltigkeitbeschutzenvonangreifendurchihrraubgierigfeindewelchevoralternzwolftausend
            jahresvorandieerscheinenvanderersteerdemenschderraumschiffgebrauchlichtalsseinursprungvonkraftgestartsein
            langefahrthinzwischensternartigraumaufdersuchenachdiesternwelchegehabtbewohnbarplanetenkreisedrehensichund
            wohinderneurassevonverstandigmenschlichkeitkonntefortpflanzenundsicherfreuenanlebenslanglichfreudeundruhemit
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

  describe 'veteran last name is malformed' do
    describe 'missing' do
      it 'raises a missing exception' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => nil,
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect do
          SimpleFormsApi::MetadataValidator.validate(metadata)
        end.to raise_error(ArgumentError, 'veteran last name is missing')
      end
    end

    describe 'non-string' do
      it 'raises a non-string exception' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 13,
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect do
          SimpleFormsApi::MetadataValidator.validate(metadata)
        end.to raise_error(ArgumentError,
                         'veteran last name is not a string')
      end
    end

    describe 'too long' do
      it 'returns metadata with first 50 characters of veteran last name' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 'Wolfeschlegelsteinhausenbergerdorffwelchevoralternwarengewissenhaftschaferswessenschafe
            warenwohlgepflegeundsorgfaltigkeitbeschutzenvonangreifendurchihrraubgierigfeindewelchevoralternzwolftausend
            jahresvorandieerscheinenvanderersteerdemenschderraumschiffgebrauchlichtalsseinursprungvonkraftgestartsein
            langefahrthinzwischensternartigraumaufdersuchenachdiesternwelchegehabtbewohnbarplanetenkreisedrehensichund
            wohinderneurassevonverstandigmenschlichkeitkonntefortpflanzenundsicherfreuenanlebenslanglichfreudeundruhemit
            nichteinfurchtvorangreifenvonandererintelligentgeschopfsvonhinzwischensternartigraum',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }
        expected_metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 'Wolfeschlegelsteinhausenbergerdorffwelchevoraltern',
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
      it 'returns metadata with disallowed characters of veteran last name stripped' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => '2John~! - Jo/hn?\\',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }
        expected_metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 'John - Jo/hn',
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

  describe 'veteran file number is malformed' do
    describe 'missing' do
      it 'raises a missing exception' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 'Doe',
          'fileNumber' => nil,
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect do
          SimpleFormsApi::MetadataValidator.validate(metadata)
        end.to raise_error(ArgumentError, 'file number is missing')
      end
    end

    describe 'non-string' do
      it 'raises a non-string exception' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 'Doe',
          'fileNumber' => 444_444_444,
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect do
          SimpleFormsApi::MetadataValidator.validate(metadata)
        end.to raise_error(ArgumentError,
                         'file number is not a string')
      end
    end

    describe 'too long' do
      it 'raises an exception' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 'Doe',
          'fileNumber' => '4444444442789',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        expect do
          SimpleFormsApi::MetadataValidator.validate(metadata)
        end.to raise_error(ArgumentError,
                         'file number is invalid. It must be 8 or 9 digits')
      end
    end
  end
end
