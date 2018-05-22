module Vet360Redis
  class Cache
    def self.invalidate(user)
      user.vet360_contact_info&.destroy
    end
  end
end
