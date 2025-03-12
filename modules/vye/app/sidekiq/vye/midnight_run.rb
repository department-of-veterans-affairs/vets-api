# frozen_string_literal: true

# rubocop:disable Style/BlockComments
=begin
Summary of process - Hopefully, this helps explain what's going on to the newly initialized maintainer of this code
  Ingress BDN
   Creates BDNClone
   Vye::BatchTransfer::BdnChunk.build_chunks and assigns to chunks
     note that build_chunks is actually in the parent class of BdnChunk, Vye::BatchTransfer::Chunk which is confusing
          this is because TimsChunk is a child of Vye::BatchTransfer::Chunk and also builds chunks

     instantiates Vye::BatchTransfer::Chunking with parameters filename & block_size as an array
     splits that array into chunks
       downloads the file and splits it into chunks
       passes the array of chunks back to it's caller above

     uploads each chunk to S3 (the actual method for this lives in CloudTransfer)

     imports each chunk (located in BdnChunk proper) into the database
       deletes from UserInfo any existing rows for this batch under the BdnClone
         relies on referential integrity rules to delete any existing
           address changes, awards, & direct deposit changes
           it also sets the user_info_id to null in any verifications tied to the user profile
           this has the potential to be a performance bottleneck
        line by line loads the data via Vye::LoadData.new(...)
          This snippet
            UserProfile.transaction do
              send(source, **records)
            end
          is referring to method bdn_feed in this context in this class
          so essentially it's creating the UserProfile, UserInfo, UserAddress and UserAward rows as needed
          source is :bdn_feed as defined in BdnChunk
=end
# rubocop:enable Style/BlockComments

module Vye
  class MidnightRun
    include Sidekiq::Worker

    def perform
      Rails.logger.info('Vye::MidnightRun starting')
      IngressBdn.perform_async
      Rails.logger.info('Vye::MidnightRun finished')
    end
  end
end
