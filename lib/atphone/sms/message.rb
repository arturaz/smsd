#!/usr/bin/env ruby

# Class for representing SMS message
class ATPhone::SMS::Message # {{{
    require 'atphone/sms/message/too_long.rb'

    # Maximum length of SMS message
    MAX_LENGTH_PDU_MODE = 160
    
    # Max length in text mode
    MAX_LENGTH_TEXT_MODE = 160
    
    attr_reader :number
    attr_accessor :index, :status, :message

    # Set SMS::Message target number _num_.
    #
    # number is ATPhone::Number
    def number=(num)
        if num.is_a? ATPhone::Number
            @number = num
        else
            @number = ATPhone::Number.new(num)
        end
    end
    
    # Creates SMS::Message with _msg_ message to number _num_.
    #
    # _index_ and _status_ are for messages got from ATPhone
    def initialize(msg="", num="", index=nil, status=nil)
        self.message = msg
        self.number = num
        @index = index
        @status = status
    end

    # Return message for sending in text mode
    def text
        raise ATPhone::SMS::Message::TooLong.new(MAX_LENGTH_TEXT_MODE) \
            if message.length > MAX_LENGTH_TEXT_MODE
        message
    end

    def to_s
        text = ["Number: #{@number}"]
        text.push "index: #{@index}" unless @index.nil?
        text.push "status: #{@status}" unless @status.nil?
        text.push "message: #{message.inspect}"
        text.join(', ')
    end
end # }}}
