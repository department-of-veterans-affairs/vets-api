# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    module ServiceAction
      class ExternalId < Data.define(:external_uid, :external_key)
        DEFAULT =
          new(
            external_uid: Settings.bgs.external_uid,
            external_key: Settings.bgs.external_key
          )
      end
    end
  end
end
