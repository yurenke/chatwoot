class EditMessageOnTelegramJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout,
           Net::ReadTimeout,
           Timeout::Error,
           SocketError,
           Errno::ECONNRESET,
           wait: 5.seconds,
           attempts: 3

  def perform(message_id)
    message = Message.find(message_id)

    return unless message.inbox.channel.is_a?(Channel::Telegram)

    ::Telegram::EditMessageService.new(message: message).perform
  end
end
