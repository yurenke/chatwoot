class Internal::RemoveStaleContentService
  def perform
    stale_period = 90.days.ago
    
    Rails.logger.info "[Cleanup] Task starts: resolved conversations inactive for #{stale_period} based on last activity"

    conversations_to_delete = Conversation.resolved
                                          .where('last_activity_at < ?', stale_period)

    conversations_to_delete.find_each(batch_size: 500) do |conversation|
      begin
        conversation.destroy
      rescue => e
        Rails.logger.error "[Cleanup] Remove ID #{conversation.id} failed: #{e.message}"
      end
    end

    # cleanup unattached S3 blobs
    ActiveStorage::Blob.unattached.where('created_at < ?', 2.days.ago).find_each(batch_size: 500) do |blob|
      blob.purge_later
    end

    Rails.logger.info "[Cleanup] Task completed."
  end
end