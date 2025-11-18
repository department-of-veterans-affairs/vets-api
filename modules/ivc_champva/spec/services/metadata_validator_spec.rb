# frozen_string_literal: true

require 'rails_helper'

describe IvcChampva::MetadataValidator do
  def first_name
    return 'sponsorFirstName' if Flipper.enabled?(:champva_update_metadata_keys)

    'veteranFirstName'
  end

  def last_name
    return 'sponsorLastName' if Flipper.enabled?(:champva_update_metadata_keys)

    'veteranLastName'
  end

  def first_name_error_label
    return 'sponsor first name' if Flipper.enabled?(:champva_update_metadata_keys)

    'veteran first name'
  end

  def set_flipper(enabled)
    allow(Flipper).to(
      receive(:enabled?).with(:champva_update_metadata_keys).and_return(enabled)
    )
  end

  [true, false].each do |champva_update_metadata_keys_enabled|
    # before do
    #   allow(Flipper).to(
    #     receive(:enabled?).with(:champva_update_metadata_keys).and_return(champva_update_metadata_keys_enabled)
    #   )
    # end

    describe 'metadata is valid' do
      it 'returns unmodified metadata' do
        set_flipper(champva_update_metadata_keys_enabled)

        metadata = {
          first_name => 'John',
          last_name => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq(metadata)
      end
    end

    describe 'metadata key has a missing value' do
      it 'raises a missing exception' do
        set_flipper(champva_update_metadata_keys_enabled)

        expect do
          IvcChampva::MetadataValidator.validate_presence_and_stringiness(nil, first_name_error_label)
        end.to raise_error(ArgumentError, "#{first_name_error_label} is missing")
      end
    end

    describe 'metadata key has a non-string value' do
      it 'raises a non-string exception' do
        set_flipper(champva_update_metadata_keys_enabled)

        expect do
          IvcChampva::MetadataValidator.validate_presence_and_stringiness(12, first_name_error_label)
        end.to raise_error(ArgumentError, "#{first_name_error_label} is not a string")
      end
    end

    describe 'first name is malformed' do
      describe 'too long' do
        it 'returns metadata with first 50 characters of the first name' do
          set_flipper(champva_update_metadata_keys_enabled)

          # rubocop:disable Layout/LineLength
          metadata = {
            first_name => 'Wolfeschlegelsteinhausenbergerdorffwelchevoralternwarengewissenhaftschaferswessenschafe
              warenwohlgepflegeundsorgfaltigkeitbeschutzenvonangreifendurchihrraubgierigfeindewelchevoralternzwolftausend
              jahresvorandieerscheinenvanderersteerdemenschderraumschiffgebrauchlichtalsseinursprungvonkraftgestartsein
              langefahrthinzwischensternartigraumaufdersuchenachdiesternwelchegehabtbewohnbarplanetenkreisedrehensichund
              wohinderneurassevonverstandigmenschlichkeitkonntefortpflanzenundsicherfreuenanlebenslanglichfreudeundruhemit
              nichteinfurchtvorangreifenvonandererintelligentgeschopfsvonhinzwischensternartigraum',
            last_name => 'Doe',
            'fileNumber' => '444444444',
            'zipCode' => '12345',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }
          # rubocop:enable Layout/LineLength
          expected_metadata = {
            first_name => 'Wolfeschlegelsteinhausenbergerdorffwelchevoraltern',
            last_name => 'Doe',
            'fileNumber' => '444444444',
            'zipCode' => '12345',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }

          validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

          expect(validated_metadata).to eq expected_metadata
        end
      end

      describe 'contains disallowed characters' do
        it 'returns metadata with disallowed characters of first name stripped or corrected' do
          set_flipper(champva_update_metadata_keys_enabled)

          metadata = {
            first_name => '2Jöhn~! - Jo/hn?\\',
            last_name => 'Doe',
            'fileNumber' => '444444444',
            'zipCode' => '12345',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }
          expected_metadata = {
            first_name => 'John - Jo/hn',
            last_name => 'Doe',
            'fileNumber' => '444444444',
            'zipCode' => '12345',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }

          validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

          expect(validated_metadata).to eq expected_metadata
        end
      end
    end

    describe 'last name is malformed' do
      describe 'too long' do
        it 'returns metadata with first 50 characters of last name' do
          set_flipper(champva_update_metadata_keys_enabled)

          # rubocop:disable Layout/LineLength
          metadata = {
            first_name => 'John',
            last_name => 'Wolfeschlegelsteinhausenbergerdorffwelchevoralternwarengewissenhaftschaferswessenschafe
              warenwohlgepflegeundsorgfaltigkeitbeschutzenvonangreifendurchihrraubgierigfeindewelchevoralternzwolftausend
              jahresvorandieerscheinenvanderersteerdemenschderraumschiffgebrauchlichtalsseinursprungvonkraftgestartsein
              langefahrthinzwischensternartigraumaufdersuchenachdiesternwelchegehabtbewohnbarplanetenkreisedrehensichund
              wohinderneurassevonverstandigmenschlichkeitkonntefortpflanzenundsicherfreuenanlebenslanglichfreudeundruhemit
              nichteinfurchtvorangreifenvonandererintelligentgeschopfsvonhinzwischensternartigraum',
            'fileNumber' => '444444444',
            'zipCode' => '12345',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }
          # rubocop:enable Layout/LineLength
          expected_metadata = {
            first_name => 'John',
            last_name => 'Wolfeschlegelsteinhausenbergerdorffwelchevoraltern',
            'fileNumber' => '444444444',
            'zipCode' => '12345',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }

          validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

          expect(validated_metadata).to eq expected_metadata
        end
      end

      describe 'contains disallowed characters' do
        it 'returns metadata with disallowed characters of last name stripped or corrected' do
          set_flipper(champva_update_metadata_keys_enabled)

          metadata = {
            first_name => 'John',
            last_name => '2Jöh’n~! - J\'o/hn?\\',
            'fileNumber' => '444444444',
            'zipCode' => '12345',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }
          expected_metadata = {
            first_name => 'John',
            last_name => 'John - Jo/hn',
            'fileNumber' => '444444444',
            'zipCode' => '12345',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }

          validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

          expect(validated_metadata).to eq expected_metadata
        end
      end
    end

    describe 'file number is malformed' do
      describe 'too long' do
        it 'raises an exception' do
          set_flipper(champva_update_metadata_keys_enabled)

          metadata = {
            first_name => 'John',
            last_name => 'Doe',
            'fileNumber' => '4444444442789',
            'zipCode' => '12345',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }

          expect do
            IvcChampva::MetadataValidator.validate(metadata)
          end.to raise_error(ArgumentError, 'file number is invalid. It must be 8 or 9 digits')
        end
      end

      describe 'missing' do
        it 'succeeds' do
          set_flipper(champva_update_metadata_keys_enabled)

          metadata = {
            first_name => 'John',
            last_name => 'Doe',
            'fileNumber' => '',
            'zipCode' => '12345',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }

          validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

          expect(validated_metadata).to eq(metadata)
        end
      end
    end

    describe 'zip code is malformed' do
      it 'defaults to 00000' do
        set_flipper(champva_update_metadata_keys_enabled)

        metadata = {
          first_name => 'John',
          last_name => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '1234567890',
          'country' => 'USA',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }
        expected_metadata = {
          first_name => 'John',
          last_name => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '00000',
          'country' => 'USA',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end
    end

    describe 'zip code is 9 digits long' do
      it 'is transformed to a 5+4 format US zip code' do
        set_flipper(champva_update_metadata_keys_enabled)

        metadata = {
          first_name => 'John',
          last_name => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '123456789',
          'country' => 'USA',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }
        expected_metadata = {
          first_name => 'John',
          last_name => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345-6789',
          'country' => 'USA',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end
    end

    describe 'zip code is not US based' do
      it 'is set to 00000' do
        set_flipper(champva_update_metadata_keys_enabled)

        metadata = {
          first_name => 'John',
          last_name => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '12345',
          'country' => 'CA',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }
        expected_metadata = {
          first_name => 'John',
          last_name => 'Doe',
          'fileNumber' => '444444444',
          'zipCode' => '00000',
          'country' => 'CA',
          'source' => 'VA Platform Digital Forms',
          'docType' => '21-0845',
          'businessLine' => 'CMP'
        }

        validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

        expect(validated_metadata).to eq expected_metadata
      end

      describe 'zip code is nil' do
        it 'is set to 00000' do
          set_flipper(champva_update_metadata_keys_enabled)

          metadata = {
            first_name => 'John',
            last_name => 'Doe',
            'fileNumber' => '444444444',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }
          expected_metadata = {
            first_name => 'John',
            last_name => 'Doe',
            'fileNumber' => '444444444',
            'zipCode' => '00000',
            'country' => 'USA',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-0845',
            'businessLine' => 'CMP'
          }

          validated_metadata = IvcChampva::MetadataValidator.validate(metadata)

          expect(validated_metadata).to eq expected_metadata
        end
      end
    end
  end
end
