#!/usr/bin/env ruby
# Class for holding SMS messages
class ATPhone::SMS < Array # {{{
    require 'atphone/sms/message.rb'

    # Initialize SMS, store ATPhone reference inside
    def initialize(phone)
        @phone = phone
    end

    # Same as Array#each except it excludes nil messages
    def each(&block)
        msgs = []
        super { |msg| msgs.push(msg) unless msg.nil? }
        msgs.each(&block)
    end

    # Deletes message from object and phone memory
    def delete(index)
        if index.is_a? ATPhone::SMS::Message
            index = index.index
        end

        self[index] = nil
        @phone.send("AT+CMGD=#{index}")
    end

    # Delete all messages from object and phone memory
    def delete_all
        each { |msg| delete(msg) }
        clear
    end
end # }}}
