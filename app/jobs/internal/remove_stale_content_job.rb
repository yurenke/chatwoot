class Internal::RemoveStaleContentJob < ApplicationJob
  queue_as :housekeeping

  def perform
    Internal::RemoveStaleContentService.new.perform
  end
end