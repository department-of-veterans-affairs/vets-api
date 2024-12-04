# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api/submission/metadata_validator'

describe SimpleFormsApi::Submission::MetadataValidator do
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

      validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata)

      expect(validated_metadata).to eq(metadata)
    end
  end

  describe 'metadata key has a missing value' do
    it 'raises a missing exception' do
      expect do
        SimpleFormsApiSubmission::MetadataValidator.validate_presence_and_stringiness(nil, 'veteran first name')
      end.to raise_error(ArgumentError, 'veteran first name is missing')
    end
  end

  describe 'metadata key has a non-string value' do
    it 'raises a non-string exception' do
      expect do
        SimpleFormsApiSubmission::MetadataValidator.validate_presence_and_stringiness(12, 'veteran first name')
      end.to raise_error(ArgumentError, 'veteran first name is not a string')
    end
  end

  describe 'veteran first name is malformed' do
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

        validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end
    end

    describe 'contains disallowed characters' do
      it 'returns metadata with disallowed characters of veteran first name stripped or corrected' do
        metadata = {
          'veteranFirstName' => '2Jöhn~! - Jo/hn?\\',
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

        validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end
    end
  end

  describe 'veteran last name is malformed' do
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

        validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end
    end

    describe 'contains disallowed characters' do
      it 'returns metadata with disallowed characters of veteran last name stripped or corrected' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => '2Jöh’n~! - J\'o/hn?\\',
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

        validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end
    end
  end

  describe 'file number is malformed' do
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
          SimpleFormsApiSubmission::MetadataValidator.validate(metadata)
        end.to raise_error(ArgumentError, 'file number is invalid. It must be 8 or 9 digits')
      end
    end
  end

  describe 'zip code is malformed' do
    it 'defaults to 00000' do
      metadata = {
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '444444444',
        'zipCode' => '1234567890',
        'source' => 'VA Platform Digital Forms',
        'docType' => '21-0845',
        'businessLine' => 'CMP'
      }
      expected_metadata = {
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '444444444',
        'zipCode' => '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => '21-0845',
        'businessLine' => 'CMP'
      }

      validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata)

      expect(validated_metadata).to eq expected_metadata
    end
  end

  describe 'zip code is 9 digits long' do
    it 'is transformed to a 5+4 format US zip code' do
      metadata = {
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '444444444',
        'zipCode' => '123456789',
        'source' => 'VA Platform Digital Forms',
        'docType' => '21-0845',
        'businessLine' => 'CMP'
      }
      expected_metadata = {
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '444444444',
        'zipCode' => '12345-6789',
        'source' => 'VA Platform Digital Forms',
        'docType' => '21-0845',
        'businessLine' => 'CMP'
      }

      validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata)

      expect(validated_metadata).to eq expected_metadata
    end
  end

  describe 'zip code is not US based' do
    it 'is set to 00000' do
      metadata = {
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '444444444',
        'zipCode' => '12345',
        'source' => 'VA Platform Digital Forms',
        'docType' => '21-0845',
        'businessLine' => 'CMP'
      }
      expected_metadata = {
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '444444444',
        'zipCode' => '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => '21-0845',
        'businessLine' => 'CMP'
      }

      validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata, zip_code_is_us_based: false)

      expect(validated_metadata).to eq expected_metadata
    end

    describe 'zip code is nil' do
      it 'is set to 00000' do
        metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }
        expected_metadata = {
          'veteranFirstName' => 'John',
          'veteranLastName' => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '00000',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(metadata, zip_code_is_us_based: false)

        expect(validated_metadata).to eq expected_metadata
      end
    end
  end
end
