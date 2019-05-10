require 'taba/messenger'

module Taba
  class Base
    LOG_FILE = 'log/batch.log'.freeze
    LOG_DATE_FORMAT = '%FT%T.%L'.freeze
    SLACK_ERROR_LINE = 10

    class << self
      def run(args = nil)
        new.start(args)
      end
    end

    def initialize
      set_logger
      @times  = {}
    end

    def set_logger
      @logger = Logger.new(LOG_FILE)
      @logger.extend(ActiveSupport::Logger.broadcast(Logger.new(STDOUT)))
    end

    def start(args)
      execute_time do
        execute(args)
      end
    end

    def execute(*)
      raise NotImplementedError
    end

    def notice_info_slack(channel, attachments)
      mes = Messenger.new(:slack, channel, 'batch-checker')
      ignore_exception do
        mes.push!("バッチからの通知 [#{self.class.name}]", attachments: attachments, icon_emoji: ':slightly_smiling_face:')
      end
    end

    def notice_error(exception)
      mes = Messenger.new(:slack, '#devops', 'batch-checker')
      attachments = {
        color: 'danger',
        title: exception.inspect,
        text: exception.backtrace.take(SLACK_ERROR_LINE).join("\n"),
        fields: [
          { title: 'start', value: @times[:start].strftime(LOG_DATE_FORMAT), short: true },
          { title: 'end', value: @times[:end].strftime(LOG_DATE_FORMAT), short: true },
        ],
      }
      ignore_exception do
        mes.push!("バッチエラー [#{self.class.name}]", attachments: attachments, icon_emoji: ':fearful:')
      end
    end

    def ignore_exception
      yield
    rescue StandardError => e
      error e.inspect
      error e.backtrace.join("\n")
    end

    def info(msg)
      @logger.info(msg)
    end

    def error(msg)
      @logger.error(msg)
    end

    def execute_time
      return unless block_given?

      @times[:start] = Time.current
      info("#{self.class.name} start : #{@times[:start].strftime(LOG_DATE_FORMAT)}")
      yield
    rescue StandardError => e
      @execute_error = e
      raise
    ensure
      @times[:end] = Time.current
      info("#{self.class.name} end   : #{@times[:end].strftime(LOG_DATE_FORMAT)} diff : #{(@times[:end] - @times[:start]).to_f}")
      notice_error(e) if @execute_error
    end
  end
end
