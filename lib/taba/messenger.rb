module Taba
  class Messenger
    def initialize(_how, to, name = nil)
      to = '#devops_development' if (ENV['RAILS_ENV'] || ENV['RACK_ENV']) != 'production'

      @notifier = Slack::Notifier.new(ENV['SLACK_WEBHOOK_URL'], channel: to, username: name, link_names: 1)
    end

    def push!(message, options = {})
      if (ENV['RAILS_ENV'] || ENV['RACK_ENV']) == 'test'
        Rails.logger.debug(message) if (defined? Rails && defined? Rails.logger)
        return
      end

      @notifier.ping(message, options)
    rescue Net::OpenTimeout, Net::HTTPGatewayTimeOut
      raise 'Slack Connection Error'
    end
  end
end
