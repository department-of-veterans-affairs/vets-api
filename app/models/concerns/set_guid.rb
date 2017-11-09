module SetGuid
  extend ActiveSupport::Concern

  included do
    after_initialize do
      self.guid ||= SecureRandom.uuid
    end
  end
end
