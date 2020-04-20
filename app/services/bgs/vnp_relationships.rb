# frozen_string_literal: true

module BGS
  class VnpRelationships < Base
    def initialize(proc_id:, veteran:, dependents:, user:)
      @proc_id = proc_id
      @dependents = dependents
      @veteran = veteran

      super(user) # is this cool? Might be smelly. Might indicate a new class/object 🤔
    end

    def create
      @dependents.map do |dependent|
        create_relationship(@proc_id, @veteran.vnp_participant_id, dependent)
      end
    end
  end
end
