#!/usr/bin/env ruby
# MySQL based Sms get/send daemon.
#
# Written by Artūras Šlajus <x11@arturaz.net>

# vim:tabstop=4
# vim:softtabstop=4
# vim:shiftwidth=4

class SmsDaemon
    # Library for communicating with the phone
    $:.push 'lib/'
    require 'atphone.rb'
    
    # Database connectivity
    require 'rubygems'
    require 'active_record'

    $:.push '/home/x11/www/rails/sms/app/models/'
    %w{day_counter.rb counter.rb sms_message.rb i_sms.rb o_sms.rb}.each do |rb|
        require rb
    end

    # Sleep for x seconds
    SLEEP_BETWEEN_ACTIONS = 10
    SLEEP_BETWEEN_CYCLES = 50

    # Create new daemon
    #
    # Generic configuration:
    # *     :device         Location where device is located
    # *     :max_per_day Maximum amount of messages sent per day
    # (default: 500, -1 to disable)
    #
    # MySQL configuration:
    # *     :host             Hostname (default: localhost)
    # *     :user             Username
    # *     :pass             Password
    # *     :database     Database
    def initialize(config={})
        # Default values
        config[:host] ||= "localhost"
        config[:detach] ||= true
        config[:max_per_day] ||= 500
        
        # Initialize the logger
        @logger = Logger.new(STDOUT)
        @logger.formatter = LogFormatter.new
        @logger.progname = $0
        @logger.level = Logger::DEBUG
        
        # Connect to device
        options = {:logger => ATPhoneLogger.new(@logger)}
        options[:device] = config[:device] if config[:device]
        @phone = ATPhone.new(options)

        # Connect to database
        ActiveRecord::Base.establish_connection({
            :adapter  => "mysql", 
            :database => config[:database],
            :username => config[:user],
            :password => config[:pass],
            :hostname => config[:host],
            :socket   => '/var/run/mysqld/mysqld.sock'
        })
        suppress(ActiveRecord::StatementInvalid) do
            ActiveRecord::Base.connection.execute 'SET NAMES UTF8'
        end

        # Initialize the counter
        Counter.max_per_day = config[:max_per_day]

        # Store the config
        @config = config
    end

    # Run the daemon
    #
    # Starts processing messages
    def run
        @logger.info("Started.")
        begin
            loop do
                process_incoming
                @logger.debug("Sleeping between actions for " +
                    "#{SLEEP_BETWEEN_ACTIONS} seconds.")
                sleep SLEEP_BETWEEN_ACTIONS
                process_outgoing
                @logger.debug("Sleeping between cycles for " +
                    "#{SLEEP_BETWEEN_CYCLES} seconds")
                sleep SLEEP_BETWEEN_CYCLES
            end
        rescue Interrupt
            @logger.info("Quitting.")
            exit
        end
    end

    # Processes incoming Sms messages
    #
    # Executes and logs control ones, stores others
    def process_incoming
        @logger.debug("Processing incoming.")
        # Incoming messages
        msgs = @phone.messages
        msgs.each do |msg|
            @logger.info("Incoming Sms: #{msg.to_s}.")
            @logger.debug(msg.inspect)
            sms = ISms.new({
                :number => msg.number,
                :message => msg.message,
            })

            if sms.save
                @logger.info("Sms saved to SQL: #{sms.to_s}.")
                @logger.debug(sms.inspect)
                
                msgs.delete(msg)
                @logger.info("Sms deleted from phone: #{msg.to_s}.")
                @logger.debug(msg.inspect)
            end
        end
    end

    # Send outgoing messages from MySQL
    def process_outgoing
        @logger.debug("Processing outgoing.")
        # Outgoing messages
        to_send = OSms.find(
            :all,
            :conditions => [
                "status IS NULL " +
                " AND (delayed_at <> ? OR delayed_at IS NULL)" +
                " AND (send_at <= NOW() OR send_at IS NULL) ",
                Counter.instance.date
            ],
            :order => "created_on,id ASC"
        )

        to_send.each do |sms|
            begin
                Counter.instance.increment
                @phone.sms(sms.number, sms.message)
            rescue ATPhone::Number::Invalid, \
                    ATPhone::SMS::Message::TooLong => e
                @logger.error("#{sms.to_s} sending failed: #{e}.")
                @logger.debug(sms.inspect)
                @logger.debug(e.inspect)

                sms.status = 'FAIL'
                sms.info = "Error sending SMS: #{e}"
            # We cannot send more messages today
            rescue DayCounter::NotAllowed
                @logger.info("SMS delayed, max " +
                    "#{Counter.instance.max_per_day}/day: #{sms.to_s}.")
                @logger.debug(sms.inspect)
            
                sms.delayed_at = Counter.instance.date
                sms.info = "Delayed because " +
                    "#{Counter.instance.max_per_day} messages per day " +
                    "limit reached for #{Counter.instance.date}"
            else
                @logger.info("SMS sent: #{sms.to_s}")
                @logger.debug(sms.inspect)

                sms.sent = Time.now.strftime("%Y-%m-%d %H:%M:%S")
                sms.status = 'SENT'
            ensure
                sms.save!
            end
        end
    end

    # Transitional class for directing ATPhone log messages to SmsD Logger
    class ATPhoneLogger # {{{
        def initialize(logger)
            @logger = logger
        end

        def log(msg)
            @logger.debug("atphone") { msg }
        end
    end # }}}

    # Log formatter
    class LogFormatter # {{{
        def call(severity, time, progname, msg)
            str = "%s [%s, %s]: %s\n" % [
                time.strftime("%Y-%m-%d %H:%M:%S"),
                progname,
                severity,
                msg
            ]
        end
    end # }}}
end

# YAML for configuration
require 'yaml'


smsd = SmsDaemon.new(
    :user => "",
    :pass => "",
    :database => ""
)
smsd.run
