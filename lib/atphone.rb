#!/usr/bin/env ruby
# Written by Artūras Šlajus <x11@arturaz.net> 

# vim:tabstop=2
# vim:softtabstop=2
# vim:shiftwidth=2

# Somehow this does not like to be in a class
require 'serialport'

# Communicates with AT phones
class ATPhone # {{{
    require 'timeout'
    include Timeout

    require 'atphone/error'
    require 'atphone/logger'
    require 'atphone/number'
    require 'atphone/sms'

    # New line
    NL = "\r\n"
    
    # End of message
    EOM = 0x1a.chr
    
    # Read occurs each READ_TIMEOUT msec
    READ_TIMEOUT = 800

    # Time to wait for SMS message to be sent (will only wait once)
    SMS_SEND_TIMEOUT = 5000


    # Opens new connection to _device_
    def initialize(options={})
        # Default options
        options[:device] ||= '/dev/ttyACM0'
        options[:logger] ||= false
        
        if [true, false].include? options[:logger]
            @logger = ATPhone::Logger.new(options[:logger])
        else
            @logger = options[:logger]
        end

        init_device(options[:device])
    end

    def init_device(device)
        @logger.log("Initializing device #{device}.")
        
        @dev = SerialPort.new(device, 19200, 8, 1, SerialPort::NONE)

        # Transfers the modem from data mode to command mode.
        raw_send('+++')

        # Lots of AT commands:
        # Force modem on-hook (hang-up)/
        #send('AT H0 Z S7=45 S0=0 Q0 V1 E0 &C0 X4')

        # Echo off
        send('ATE0')
    end
    
    # Issues raw command _cmd_ to phone
    # 
    # Strips newlines from ends of response. Returns data got from phone.
    #
    # Raises ATPhone::Error if phone reports error.
    def raw_send(cmd, msec=READ_TIMEOUT)
        # Write
        @logger.log("->[PHONE] #{cmd.inspect}")
        
        @dev.read_timeout = msec
        @dev.write(cmd)
        
        # Read
        data = @dev.read
        @logger.log("<-[PHONE] #{data.inspect}")

        # Change all \r\n into \n
        data.gsub!(/\r\n?/, "\n")
        # Remove newlines from start and end
        data.gsub!(/^\n*(.*?)\n*$/, '\1')

        if /ERROR$/.match(data)
            raise ATPhone::Error(data)
        end
        
        data.gsub!(/\n*OK$/, '')

        @logger.log("<- #{data.inspect}")

        data
    end

    # Issues command _cmd_ to phone with NL appended.
    #
    # See ATPhone#raw_send.
    def send(cmd, msec=READ_TIMEOUT)
        raw_send(cmd + NL, msec)
    end

    # Send SMS::Message _message_ to _number_
    def sms(number, message, sec=SMS_SEND_TIMEOUT)
        @logger.log("Sending message.")

        msg = ATPhone::SMS::Message.new(message, number)
        
        # Turn on text mode
        send("AT+CMGF=1")
        # Specify number
        raw_send("AT+CMGS=\"#{msg.number}\"\r")
        # send message
        raw_send(msg.text + EOM, sec)
    end

    # Get messages from phone.
    #
    # Returns ATPhone::SMS
    def messages
        @logger.log("Getting messages from phone.")
    
        # Get a list of messages
        msg = nil
        msgs = ATPhone::SMS.new(self)

        # Turn on text mode
        send("AT+CMGF=1")
        
        resp = send("AT+CMGL")
        resp.each_line do |line|
            # If it is a message header
            if line[0..5] == '+CMGL:'
                # Add formed message to list
                msgs[msg.index] = msg unless msg.nil?
                
                # Create new message from phone data
                index, status, number = line[7..-1].split(',')
                msg = ATPhone::SMS::Message.new(
                    "",
                    number.strip.gsub('"', ''),
                    index.to_i,
                    status.strip.gsub('"', '')
                )
            # If it's not a command, then it's text
            elsif not msg.nil?
                msg.message += line
            end
        end

        # Add last message
        msgs[msg.index] = msg unless msg.nil?

        msgs
    end
end # }}}
