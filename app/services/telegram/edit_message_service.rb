class Telegram::EditMessageService
  def initialize(message:)
    @message = message
  end

  def perform
    channel.edit_message_on_telegram(message)
  end

  private

  attr_reader :message

  def channel
    @channel ||= message.inbox.channel
  end
end
