# frozen_string_literal: true

module KmsEncryptedModelPatch
  extend self

  KMS_KEY_ROTATION_DATE = Date.new(Time.zone.today.year, 10, 12)

  # rubocop:disable Naming/PredicateName
  def has_kms_key
    # implicitly calls #has_kms_key with specified options, so that we don't need to require it
    # of future encrypted models
    super(**kms_options)
  end
  # rubocop:enable Naming/PredicateName

  def kms_version
    Time.zone.today < KMS_KEY_ROTATION_DATE ? Time.zone.today.year - 1 : Time.zone.today.year
  end

  private

  def kms_options
    # Enumerate key_ids so that all years/previous versions are accounted for. Every
    # version should point to the same key_id
    previous_versions = Hash.new do |hash, key|
      hash[key] = { key_id: KmsEncrypted.key_id }
    end

    {
      version: kms_version,
      previous_versions:
    }
  end
end
